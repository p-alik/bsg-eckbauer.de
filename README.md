# bsg-eckbauer.de

Website of **[Berliner Schachgesellschaft 1827 Eckbauer e.V.](https://bsg-eckbauer.de/)**

## Repository layout

```
themes/
├── v3/          ← WordPress theme "Eckbauer v3" (legacy)
└── eckbauer/    ← Child theme of Twenty Ten (active) — CSS/JS customisations
flake.nix        ← Nix flake: local WordPress dev environment
flake.lock
```

## Local development

[Nix](https://nixos.org/) is required (flakes must be enabled).

```bash
nix run
```

That single command:

1. Downloads WordPress core (German locale) into `.wordpress/`
2. Starts a private MariaDB instance in `.mysql/` on port 3307
3. Creates the `wordpress` database and user
4. Symlinks `themes/eckbauer/` → `.wordpress/wp-content/themes/eckbauer`
5. Activates the child theme and sets `/%postname%/` permalinks
6. Starts PHP's built-in web server

WordPress is then available at **<http://localhost:8080>**.
Admin panel: **<http://localhost:8080/wp-admin>** — credentials `admin` / `admin`.

Press `Ctrl-C` to stop; MariaDB shuts down cleanly.

Subsequent runs skip the download/install steps and start the server directly.

### Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `WP_DIR` | `.wordpress` | WordPress installation directory |
| `MYSQL_DIR` | `.mysql` | MariaDB data directory |
| `WP_PORT` | `8080` | Port for the PHP built-in server |

```bash
WP_PORT=9090 nix run
```

### Package the child theme for production

Only WP admin access is available on the live server, so the child theme is deployed
by uploading a zip via **Appearance → Themes → Add New → Upload Theme**:

```bash
nix run .#theme-zip
```

This creates `eckbauer.zip` in the repo root. Upload it through the WP admin panel,
then activate **Eckbauer** under Appearance → Themes.

### Dev shell

For direct access to `php`, `mysql`, and `wp` (WP-CLI):

```bash
nix develop
```

## Importing an UpdraftPlus backup

UpdraftPlus splits a backup into several zip files:

```
backup_YYYY-MM-DD-HHMM_<hash>_db.gz          ← database
backup_YYYY-MM-DD-HHMM_<hash>_uploads.zip    ← wp-content/uploads
backup_YYYY-MM-DD-HHMM_<hash>_plugins.zip    ← wp-content/plugins
backup_YYYY-MM-DD-HHMM_<hash>_themes.zip     ← wp-content/themes
backup_YYYY-MM-DD-HHMM_<hash>_others.zip     ← everything else
```

### Prerequisites

`wp db import` requires a working `wp-config.php` to know the database credentials.
Run `nix run` once to let it bootstrap WordPress, then stop it with `Ctrl-C`:

```bash
nix run    # bootstraps .wordpress/ and .mysql/, then Ctrl-C to stop
```

Open a dev shell for the remaining steps:

```bash
nix develop
```

### 1 — Restore the original theme

Extract the themes archive first so the original theme is present before the database
is imported. `nix run` creates a symlink for `eckbauer-v3`; the zip may overwrite it
with real files — that is fine for reviewing the original, and the symlink can be
restored later when developing.

The zip contains a `themes/` directory at its root, so unzip one level up into
`wp-content/` — not into `wp-content/themes/` — to avoid double-nesting:

```bash
unzip backup_*_themes.zip -d .wordpress/wp-content/
```

### 2 — Restore the database

UpdraftPlus stores the database dump as a `.gz` file. After decompression the file has
no `.sql` extension, so it must be renamed before `wp db import` will accept it.
The `#`-style line comments used by UpdraftPlus are valid MariaDB/MySQL syntax —
no further pre-processing is needed.

```bash
gunzip -k backup_*_db.gz            # produces backup_*_db  (no extension)
mv backup_*_db{,.sql}               # rename to backup_*_db.sql

wp db import backup_*_db.sql --path=.wordpress
wp search-replace 'https://bsg-eckbauer.de/v2' 'http://localhost:8080' \
  --path=.wordpress \
  --all-tables \
  --report-changed-only
```

### 3 — Restore uploads

The zip contains an `uploads/` directory at its root — unzip into `wp-content/`,
not into `wp-content/uploads/`:

```bash
unzip backup_*_uploads.zip -d .wordpress/wp-content/
```

### 4 — Restore plugins (optional)

Same pattern — unzip into `wp-content/`:

```bash
unzip backup_*_plugins.zip -d .wordpress/wp-content/
```

### 5 — Deactivate SSL-forcing plugins and fix URLs

After restoring plugins, security plugins (e.g. `better-wp-security` / iThemes Security)
may switch `siteurl` and `home` to `https`, causing the PHP built-in server to receive
SSL handshake requests it cannot handle. Deactivate the plugin and reset the URLs:

```bash
wp plugin deactivate better-wp-security --path=.wordpress
wp option update siteurl "http://localhost:8080" --path=.wordpress
wp option update home    "http://localhost:8080" --path=.wordpress
```

### 6 — Flush rewrite rules

```bash
wp rewrite flush --hard --path=.wordpress
```

### Switch to the repo theme (development)

Once you are done reviewing the original and want to work on `themes/v3/`, replace the
extracted theme directory with the symlink:

```bash
rm -rf .wordpress/wp-content/themes/eckbauer-v3
ln -sf "$(pwd)/themes/v3" .wordpress/wp-content/themes/eckbauer-v3
wp theme activate eckbauer-v3 --path=.wordpress
```

### 5 — Verify

Open <http://localhost:8080> — the site should look identical to the live version. Log in at <http://localhost:8080/wp-admin> with the credentials from the backup (or reset with `wp user update admin --user_pass=admin --path=.wordpress`).

---

## Theme — Eckbauer (child of Twenty Ten)

A child theme that extends the built-in Twenty Ten theme with BSG Eckbauer design
customisations. Only the overrides live in this repo; the parent theme ships with
WordPress and requires no special setup.

### File structure

```
themes/eckbauer/
├── style.css       ← Child theme header + CSS overrides
└── functions.php   ← Enqueues parent + child stylesheets
```

Add custom JS by enqueuing it from `functions.php`.

### Deployment

```bash
nix run .#theme-zip   # → eckbauer.zip
```

Upload `eckbauer.zip` via **WP Admin → Appearance → Themes → Add New → Upload Theme**.

---

## Theme — Eckbauer v3 (legacy)

Classic dark-charcoal & gold WordPress theme (no longer active).

### File structure

```
themes/v3/
├── style.css           ← Theme metadata + all CSS
├── functions.php       ← Theme setup, menus, sidebars, helpers
├── header.php          ← Topbar, site header, navigation
├── footer.php          ← Footer
├── sidebar.php         ← Right sidebar
├── index.php           ← Blog homepage
├── single.php          ← Single post
├── page.php            ← Static page
├── archive.php         ← Category / tag / date archives
├── search.php          ← Search results
├── 404.php             ← Not found
├── comments.php        ← Comment list + reply form
└── js/
    └── main.js         ← Mobile menu toggle
```
