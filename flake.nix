{
  description = "BSG Eckbauer – local WordPress development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    # PHP 8.3 with the extensions WordPress needs
    php = pkgs.php83.buildEnv {
      extensions = ({ enabled, all }: enabled ++ (with all; [
        mysqli
        pdo_mysql
        gd
        zip
        curl
        mbstring
        intl
        opcache
      ]));
      extraConfig = ''
        upload_max_filesize = 64M
        post_max_size      = 64M
        memory_limit       = 256M
        display_errors     = On
        error_reporting    = E_ALL
      '';
    };

    # Minimal PHP router so pretty-permalinks work with php -S
    wpRouter = pkgs.writeText "wp-router.php" ''
      <?php
      $uri  = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
      $file = __DIR__ . $uri;
      if ($uri !== '/' && file_exists($file) && !is_dir($file)) {
          return false; // serve static files as-is
      }
      require_once __DIR__ . '/index.php';
    '';

    # Main start-up script
    wpDev = pkgs.writeShellApplication {
      name = "wp-dev";
      runtimeInputs = [ php pkgs.mariadb pkgs.wp-cli pkgs.coreutils ];
      text = ''
        # ── configurable paths / ports ──────────────────────────────────────
        REPO_ROOT="$(pwd)"
        WP_DIR="''${WP_DIR:-$REPO_ROOT/.wordpress}"
        MYSQL_DIR="''${MYSQL_DIR:-$REPO_ROOT/.mysql}"
        WP_PORT="''${WP_PORT:-8080}"
        WP_BIND="''${WP_BIND:-0.0.0.0}"
        DB_PORT=3307          # private port, avoids conflicts with system MySQL
        DB_HOST="127.0.0.1"
        DB_NAME=wordpress
        DB_USER=wordpress
        DB_PASS=wordpress
        # Persist WP_HOST across runs: env var → saved file → localhost
        WP_HOST_FILE="$REPO_ROOT/.wp-host"
        if [ -n "''${WP_HOST:-}" ]; then
          echo "$WP_HOST" > "$WP_HOST_FILE"
        else
          WP_HOST="$(cat "$WP_HOST_FILE" 2>/dev/null || echo localhost)"
        fi
        WP_URL="http://''${WP_HOST}:$WP_PORT"
        MYSQL_PID="$MYSQL_DIR/mysqld.pid"
        MYSQL_SOCK="$MYSQL_DIR/mysqld.sock"

        mkdir -p "$WP_DIR" "$MYSQL_DIR"

        # ── MariaDB ──────────────────────────────────────────────────────────
        if [ ! -d "$MYSQL_DIR/mysql" ]; then
          echo "==> Initialising MariaDB data directory..."
          mysql_install_db \
            --datadir="$MYSQL_DIR" \
            --skip-test-db \
            --auth-root-authentication-method=normal 2>/dev/null \
            || mysql_install_db --datadir="$MYSQL_DIR" --skip-test-db
        fi

        # Check whether our private instance is already up
        if mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
               --connect-timeout=1 ping 2>/dev/null | grep -q alive; then
          echo "==> MariaDB already running on port $DB_PORT"
        else
          echo "==> Starting MariaDB on port $DB_PORT..."
          mysqld \
            --datadir="$MYSQL_DIR" \
            --socket="$MYSQL_SOCK" \
            --port="$DB_PORT" \
            --bind-address="$DB_HOST" \
            --pid-file="$MYSQL_PID" \
            --log-error="$MYSQL_DIR/error.log" \
            --skip-networking=0 \
            --user="$(id -un)" &

          echo -n "    Waiting for MariaDB..."
          for _ in $(seq 1 30); do
            mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
              --connect-timeout=1 ping 2>/dev/null | grep -q alive && break
            printf '.'
            sleep 1
          done
          echo ""
          if ! mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
                  --connect-timeout=1 ping 2>/dev/null | grep -q alive; then
            echo "ERROR: MariaDB did not start. Check $MYSQL_DIR/error.log"
            exit 1
          fi
        fi

        # Ensure database + user exist
        mysql -h "$DB_HOST" -P "$DB_PORT" -u root <<SQL
        CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`
          CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE USER IF NOT EXISTS '$DB_USER'@'$DB_HOST'
          IDENTIFIED BY '$DB_PASS';
        GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'$DB_HOST';
        FLUSH PRIVILEGES;
        SQL

        # ── WordPress core ───────────────────────────────────────────────────
        if [ ! -f "$WP_DIR/wp-login.php" ]; then
          echo "==> Downloading WordPress (de_DE)..."
          wp core download --path="$WP_DIR" --locale=de_DE

          wp config create --path="$WP_DIR" \
            --dbname="$DB_NAME" \
            --dbuser="$DB_USER" \
            --dbpass="$DB_PASS" \
            --dbhost="$DB_HOST:$DB_PORT"
        fi

        if ! wp core is-installed --path="$WP_DIR" 2>/dev/null; then
          echo "==> Installing WordPress..."
          wp core install --path="$WP_DIR" \
            --url="$WP_URL" \
            --title="BSG Eckbauer 1827 e.V." \
            --admin_user=admin \
            --admin_password=admin \
            --admin_email=admin@example.com \
            --skip-email
        fi

        # ── Theme symlink ────────────────────────────────────────────────────
        THEME_LINK="$WP_DIR/wp-content/themes/eckbauer"
        THEME_SRC="$REPO_ROOT/themes/eckbauer"

        if [ ! -L "$THEME_LINK" ]; then
          echo "==> Symlinking eckbauer child theme..."
          rm -rf "$THEME_LINK"
          ln -sf "$THEME_SRC" "$THEME_LINK"
        fi

        wp theme activate eckbauer --path="$WP_DIR"

        # Pin WP_HOME / WP_SITEURL as PHP constants in wp-config.php so they
        # take absolute precedence over DB options and any plugin option locks.
        wp config set WP_HOME    "$WP_URL" --path="$WP_DIR"
        wp config set WP_SITEURL "$WP_URL" --path="$WP_DIR"

        # Rewrite any stale localhost URLs left over from a previous import
        if [ "$WP_HOST" != "localhost" ]; then
          wp search-replace "http://localhost:$WP_PORT" "$WP_URL" \
            --path="$WP_DIR" --all-tables --report-changed-only
        fi

        wp rewrite structure '/%postname%/' --path="$WP_DIR" --hard
        wp rewrite flush --hard --path="$WP_DIR"

        # ── Router file ──────────────────────────────────────────────────────
        rm -f "$WP_DIR/wp-router.php"
        cp "${wpRouter}" "$WP_DIR/wp-router.php"

        # ── Cleanup on exit ──────────────────────────────────────────────────
        cleanup() {
          echo ""
          echo "==> Shutting down MariaDB..."
          mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root shutdown 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        _w=$(( ''${#WP_URL} + 26 ))
        _sep=$(printf '─%.0s' $(seq 1 "$_w"))
        echo ""
        echo "┌''${_sep}┐"
        printf "│  %-''$((_w-4))s  │\n" "WordPress running at  $WP_URL"
        printf "│  %-''$((_w-4))s  │\n" "Admin: $WP_URL/wp-admin"
        printf "│  %-''$((_w-4))s  │\n" "Credentials: admin / admin"
        echo "└''${_sep}┘"
        echo ""

        # ── Start PHP built-in server ────────────────────────────────────────
        php -S "$WP_BIND:$WP_PORT" -t "$WP_DIR" "$WP_DIR/wp-router.php"
      '';
    };

    # ── theme-zip: package the child theme for WP admin upload ──────────────
    themeZip = pkgs.writeShellApplication {
      name = "theme-zip";
      runtimeInputs = [ pkgs.zip ];
      text = ''
        REPO_ROOT="$(pwd)"
        OUT="$REPO_ROOT/eckbauer.zip"
        rm -f "$OUT"
        cd "$REPO_ROOT/themes"
        zip -r "$OUT" eckbauer
        echo "==> Created $OUT — upload via WP Admin → Appearance → Themes → Add New"
      '';
    };

    # ── import-backup: restore an UpdraftPlus backup into the local WP instance
    importBackup = pkgs.writeShellApplication {
      name = "import-backup";
      runtimeInputs = [ pkgs.gzip pkgs.unzip pkgs.mariadb pkgs.wp-cli pkgs.coreutils ];
      text = ''
        REPO_ROOT="$(pwd)"
        BACKUP_DIR="''${1:-$REPO_ROOT}"
        WP_DIR="''${WP_DIR:-$REPO_ROOT/.wordpress}"
        MYSQL_DIR="''${MYSQL_DIR:-$REPO_ROOT/.mysql}"
        WP_PORT="''${WP_PORT:-8080}"
        # Persist WP_HOST across runs: env var → saved file → localhost
        WP_HOST_FILE="$REPO_ROOT/.wp-host"
        if [ -n "''${WP_HOST:-}" ]; then
          echo "$WP_HOST" > "$WP_HOST_FILE"
        else
          WP_HOST="$(cat "$WP_HOST_FILE" 2>/dev/null || echo localhost)"
        fi
        WP_URL="http://''${WP_HOST}:$WP_PORT"
        PROD_URL="https://bsg-eckbauer.de/v2"
        DB_PORT=3307
        DB_HOST="127.0.0.1"
        MYSQL_SOCK="$MYSQL_DIR/mysqld.sock"

        if [ ! -f "$WP_DIR/wp-config.php" ]; then
          echo "ERROR: $WP_DIR/wp-config.php not found." >&2
          echo "       Run 'nix run' once to bootstrap WordPress (then Ctrl-C), then re-run this script." >&2
          exit 1
        fi

        # ── Ensure MariaDB is running ─────────────────────────────────────────
        if ! mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
               --connect-timeout=1 ping 2>/dev/null | grep -q alive; then
          echo "==> Starting MariaDB on port $DB_PORT..."
          mysqld \
            --datadir="$MYSQL_DIR" \
            --socket="$MYSQL_SOCK" \
            --port="$DB_PORT" \
            --bind-address="$DB_HOST" \
            --log-error="$MYSQL_DIR/error.log" \
            --skip-networking=0 \
            --user="$(id -un)" &
          MYSQLD_PID=$!
          echo -n "    Waiting for MariaDB..."
          for _ in $(seq 1 30); do
            mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
              --connect-timeout=1 ping 2>/dev/null | grep -q alive && break
            printf '.'
            sleep 1
          done
          echo ""
          if ! mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root \
                  --connect-timeout=1 ping 2>/dev/null | grep -q alive; then
            echo "ERROR: MariaDB did not start. Check $MYSQL_DIR/error.log" >&2
            exit 1
          fi
          # Shut down the MariaDB we started when the script exits
          trap 'mysqladmin -h "$DB_HOST" -P "$DB_PORT" -u root shutdown 2>/dev/null || kill "$MYSQLD_PID" 2>/dev/null || true' EXIT INT TERM
        fi

        cd "$BACKUP_DIR"
        echo "==> Scanning $BACKUP_DIR for UpdraftPlus backup files..."

        shopt -s nullglob
        db_files=(backup_*-db.gz)
        themes_files=(backup_*-themes.zip)
        uploads_files=(backup_*-uploads.zip)
        plugins_files=(backup_*-plugins.zip)
        shopt -u nullglob

        DB_GZ="''${db_files[0]:-}"
        THEMES_ZIP="''${themes_files[0]:-}"
        UPLOADS_ZIP="''${uploads_files[0]:-}"
        PLUGINS_ZIP="''${plugins_files[0]:-}"

        if [ -z "$DB_GZ" ];      then echo "ERROR: no database backup (backup_*_db.gz) found in $BACKUP_DIR"      >&2; exit 1; fi
        if [ -z "$THEMES_ZIP" ]; then echo "ERROR: no themes backup (backup_*_themes.zip) found in $BACKUP_DIR"   >&2; exit 1; fi
        if [ -z "$UPLOADS_ZIP" ];then echo "ERROR: no uploads backup (backup_*_uploads.zip) found in $BACKUP_DIR" >&2; exit 1; fi

        echo "    db      : $DB_GZ"
        echo "    themes  : $THEMES_ZIP"
        echo "    uploads : $UPLOADS_ZIP"
        echo "    plugins : ''${PLUGINS_ZIP:-<none — will be skipped>}"
        echo ""
        echo "WARNING: this will overwrite the local WordPress database."
        read -r -p "Continue? [y/N] " confirm
        case "$confirm" in
          [yY]*) ;;
          *) echo "Aborted."; exit 0 ;;
        esac

        # 1 — Themes
        echo ""
        echo "==> [1/7] Restoring themes..."
        unzip -qo "$THEMES_ZIP" -d "$WP_DIR/wp-content/"

        # 2 — Database
        echo "==> [2/7] Importing database..."
        DB_SQL="''${DB_GZ%.gz}.sql"
        gunzip -kf "$DB_GZ"
        mv "''${DB_GZ%.gz}" "$DB_SQL"
        wp db import "$DB_SQL" --path="$WP_DIR"
        rm -f "$DB_SQL"

        echo "==> [2/7] Rewriting URLs: $PROD_URL -> $WP_URL..."
        wp search-replace "$PROD_URL" "$WP_URL" \
          --path="$WP_DIR" \
          --all-tables \
          --report-changed-only

        # Clean up localhost URLs left over from any previous botched import
        if [ "$WP_HOST" != "localhost" ]; then
          echo "==> [2/7] Rewriting stale localhost URLs -> $WP_URL..."
          wp search-replace "http://localhost:$WP_PORT" "$WP_URL" \
            --path="$WP_DIR" \
            --all-tables \
            --report-changed-only
        fi

        # 3 — Uploads
        echo "==> [3/7] Restoring uploads..."
        unzip -qo "$UPLOADS_ZIP" -d "$WP_DIR/wp-content/"

        # 4 — Plugins (optional)
        if [ -n "$PLUGINS_ZIP" ]; then
          echo "==> [4/7] Restoring plugins..."
          unzip -qo "$PLUGINS_ZIP" -d "$WP_DIR/wp-content/"
        else
          echo "==> [4/7] No plugins archive found — skipping."
        fi

        # 5 — Deactivate SSL plugin, fix URLs
        echo "==> [5/7] Deactivating SSL plugin and fixing URLs..."
        wp plugin deactivate better-wp-security --path="$WP_DIR" 2>/dev/null || true
        # Pin as PHP constants — takes precedence over DB options and plugin locks
        wp config set WP_HOME    "$WP_URL" --path="$WP_DIR"
        wp config set WP_SITEURL "$WP_URL" --path="$WP_DIR"

        # 6 — Rewrite rules
        echo "==> [6/7] Flushing rewrite rules..."
        wp rewrite structure '/%postname%/' --path="$WP_DIR" --hard
        wp rewrite flush --hard --path="$WP_DIR"

        # 7 — Header image + page cache
        # The eckbauer child theme stores its own theme_mods separately from the
        # parent twentyten. After a DB import that entry has no header_image key,
        # causing Twenty Ten to fall back to its bundled default (path.jpg).
        # Activate eckbauer first so the mod is written to theme_mods_eckbauer,
        # not theme_mods_twentyten (which is what the production DB restores as active).
        echo "==> [7/7] Setting header image and clearing page cache..."
        wp theme activate eckbauer --path="$WP_DIR"
        wp theme mod set header_image \
          "$WP_URL/wp-content/uploads/2019/01/cropped-ofolinimagagmoeb-1.png" \
          --path="$WP_DIR"
        rm -f "$WP_DIR/wp-content/cache/wpo-cache/''${WP_HOST}/index.html" \
              "$WP_DIR/wp-content/cache/wpo-cache/''${WP_HOST}/index.html.gz"

        echo ""
        echo "==> Import complete. Run 'nix run' to start WordPress at $WP_URL"
      '';
    };

  in {
    packages.${system} = {
      default = wpDev;
      theme-zip = themeZip;
      import-backup = importBackup;
    };

    apps.${system} = {
      default = {
        type = "app";
        program = "${wpDev}/bin/wp-dev";
      };
      theme-zip = {
        type = "app";
        program = "${themeZip}/bin/theme-zip";
      };
      import-backup = {
        type = "app";
        program = "${importBackup}/bin/import-backup";
      };
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ php pkgs.mariadb pkgs.wp-cli pkgs.zip ];
      shellHook = ''
        echo "WordPress dev tools in PATH: php, mysql, wp"
        echo "Run 'nix run' to start the local server, or 'wp-dev' inside this shell."
        echo "Run 'nix run .#theme-zip' to package the child theme for upload."
        echo "Run 'nix run .#import-backup [DIR]' to restore an UpdraftPlus backup."
      '';
    };
  };
}
