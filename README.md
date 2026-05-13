# bsg-eckbauer.de

Website of **[Berliner Schachgesellschaft 1827 Eckbauer e.V.](https://bsg-eckbauer.de/)**

## Repository layout

```
themes/
├── v3/          ← WordPress theme "Eckbauer v3" (WIP)
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
backup_YYYY-MM-DD-HHMM_<hash>_plugins.zip    ← wp-content/plugins  (optional)
backup_YYYY-MM-DD-HHMM_<hash>_themes.zip     ← wp-content/themes
backup_YYYY-MM-DD-HHMM_<hash>_others.zip     ← everything else
```

### Quick path

Bootstrap WordPress first (the DB must exist before import):

```bash
nix run    # bootstraps .wordpress/ and .mysql/, then Ctrl-C to stop
```

Place the backup files in any directory, then run:

```bash
nix run .#import-backup /path/to/backup/files
```

The directory argument defaults to the current directory.
The script will list the files it found and ask for confirmation before touching the database.

When done, `nix run` again to start the server and verify at <http://localhost:8080>.

### What the script does

| Step | Action |
|------|--------|
| 1 | Extracts `themes.zip` → `.wordpress/wp-content/` |
| 2 | Decompresses and imports the DB, then rewrites `https://bsg-eckbauer.de/v2` → `http://localhost:8080` in all tables |
| 3 | Extracts `uploads.zip` → `.wordpress/wp-content/` |
| 4 | Extracts `plugins.zip` if present, skips otherwise |
| 5 | Deactivates `better-wp-security` (prevents https redirect loop), resets `siteurl`/`home` |
| 6 | Flushes rewrite rules |
| 7 | Sets `header_image` on the `eckbauer` theme mods (the child theme has its own `theme_mods` entry separate from parent `twentyten`; without this Twenty Ten falls back to its bundled `path.jpg`), then clears the WP-Optimize page cache |

### Switch to the repo theme (development)

Once you are done reviewing the original and want to work on `themes/v3/`, replace the
extracted theme directory with the symlink:

```bash
rm -rf .wordpress/wp-content/themes/eckbauer-v3
ln -sf "$(pwd)/themes/v3" .wordpress/wp-content/themes/eckbauer-v3
wp theme activate eckbauer-v3 --path=.wordpress
```

---

## Theme — Eckbauer (child of Twenty Ten)

A child theme that extends the built-in Twenty Ten theme with BSG Eckbauer design
customisations. Only the overrides live in this repo; the parent theme ships with
WordPress and requires no special setup.

### File structure

```
themes/eckbauer/
├── style.css                          ← Child theme header + CSS overrides
├── functions.php                      ← Theme hooks (see below)
├── comments-hidden.php                ← Placeholder shown instead of comments for guests
└── assets/
    └── tinymce-table/
        └── plugin.min.js              ← TinyMCE 4.9.11 table plugin (not bundled in WP 6.x)
```

### functions.php responsibilities

| Feature | Hook |
|---|---|
| Enqueue parent (Twenty Ten) + child stylesheets | `wp_enqueue_scripts` |
| Mobile nav toggle + submenu expand buttons | `wp_footer` |
| Hide comments from guests on marked posts | `add_meta_boxes`, `save_post`, `comments_template`, `comments_array`, `get_comments_number` |
| TinyMCE table button in the classic editor | `mce_external_plugins`, `mce_buttons_3` |

### Deployment

```bash
nix run .#theme-zip   # → eckbauer.zip
```

Upload `eckbauer.zip` via **WP Admin → Appearance → Themes → Add New → Upload Theme**.

---

## Licensing

| Component | License |
|---|---|
| Theme — Eckbauer (child of Twenty Ten) | [GPL 2.0 or later](https://www.gnu.org/licenses/gpl-2.0.html) — inherited from the Twenty Ten parent theme |
| Plugin — chess-tournament | [GPL 2.0 or later](https://www.gnu.org/licenses/gpl-2.0.html) — WordPress plugins must be GPL-compatible |
| `themes/eckbauer/assets/tinymce-table/plugin.min.js` | [LGPL 2.1](https://www.gnu.org/licenses/lgpl-2.1.html) — TinyMCE 4.9.11, © Tiny Technologies, Inc. Source: [github.com/tinymce/tinymce/tree/4.9.11](https://github.com/tinymce/tinymce/tree/4.9.11) |

LGPL 2.1 is GPL-compatible; the two licenses coexist without conflict.

---

## Theme — Eckbauer v3 (WIP)

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
