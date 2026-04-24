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
        DB_PORT=3307          # private port, avoids conflicts with system MySQL
        DB_HOST="127.0.0.1"
        DB_NAME=wordpress
        DB_USER=wordpress
        DB_PASS=wordpress
        WP_URL="http://localhost:$WP_PORT"
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
        php -S "localhost:$WP_PORT" -t "$WP_DIR" "$WP_DIR/wp-router.php"
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

  in {
    packages.${system} = {
      default = wpDev;
      theme-zip = themeZip;
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
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [ php pkgs.mariadb pkgs.wp-cli pkgs.zip ];
      shellHook = ''
        echo "WordPress dev tools in PATH: php, mysql, wp"
        echo "Run 'nix run' to start the local server, or 'wp-dev' inside this shell."
        echo "Run 'nix run .#theme-zip' to package the child theme for upload."
      '';
    };
  };
}
