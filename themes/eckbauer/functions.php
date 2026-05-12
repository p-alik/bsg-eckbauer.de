<?php
add_action( 'wp_footer', function () { ?>
<script>
(function() {
  var toggle = document.querySelector('.menu-toggle');
  var nav    = document.querySelector('#access .menu-header');
  if (!toggle || !nav) return;

  toggle.addEventListener('click', function() {
    var open = nav.classList.toggle('nav-open');
    toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });

  // Inject expand-toggle buttons next to parent menu links
  nav.querySelectorAll('li').forEach(function(li) {
    var sub = li.querySelector(':scope > ul');
    if (!sub) return;
    li.classList.add('has-submenu');

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'submenu-toggle';
    btn.setAttribute('aria-expanded', 'false');
    btn.textContent = '+';

    btn.addEventListener('click', function(e) {
      e.stopPropagation();
      var open = li.classList.toggle('submenu-open');
      // setProperty with 'important' priority beats stylesheet !important rules
      if (open) {
        sub.style.setProperty('display', 'block', 'important');
      } else {
        sub.style.removeProperty('display');
      }
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      btn.textContent = open ? '−' : '+';
    });

    var link = li.querySelector(':scope > a');
    if (link) link.insertAdjacentElement('afterend', btn);
  });
})();
</script>
<?php } );

// ── Members-only comments ─────────────────────────────────────────────────────

add_action( 'add_meta_boxes', function () {
    add_meta_box(
        'eckbauer_hide_comments',
        'Kommentare',
        function ( $post ) {
            $checked = get_post_meta( $post->ID, '_hide_comments_from_guests', true );
            wp_nonce_field( 'eckbauer_hide_comments_nonce', 'eckbauer_hide_comments_nonce' );
            echo '<label><input type="checkbox" name="hide_comments_from_guests" value="1"'
                . checked( $checked, '1', false )
                . '> Nur für angemeldete Benutzer sichtbar</label>';
        },
        'post',
        'side'
    );
} );

add_action( 'save_post', function ( $post_id ) {
    if (
        ! isset( $_POST['eckbauer_hide_comments_nonce'] ) ||
        ! wp_verify_nonce( $_POST['eckbauer_hide_comments_nonce'], 'eckbauer_hide_comments_nonce' )
    ) {
        return;
    }
    if ( defined( 'DOING_AUTOSAVE' ) && DOING_AUTOSAVE ) {
        return;
    }
    if ( ! current_user_can( 'edit_post', $post_id ) ) {
        return;
    }

    if ( ! empty( $_POST['hide_comments_from_guests'] ) ) {
        update_post_meta( $post_id, '_hide_comments_from_guests', '1' );
    } else {
        delete_post_meta( $post_id, '_hide_comments_from_guests' );
    }
} );

add_filter( 'comments_template', function ( $template ) {
    if ( is_user_logged_in() ) {
        return $template;
    }
    $post_id = get_the_ID();
    if ( $post_id && get_post_meta( $post_id, '_hide_comments_from_guests', true ) === '1' ) {
        return get_stylesheet_directory() . '/comments-hidden.php';
    }
    return $template;
} );

add_filter( 'comments_array', function ( $comments, $post_id ) {
    if ( is_user_logged_in() ) {
        return $comments;
    }
    if ( get_post_meta( $post_id, '_hide_comments_from_guests', true ) === '1' ) {
        return [];
    }
    return $comments;
}, 10, 2 );

add_filter( 'get_comments_number', function ( $count, $post_id ) {
    if ( is_user_logged_in() ) {
        return $count;
    }
    if ( get_post_meta( $post_id, '_hide_comments_from_guests', true ) === '1' ) {
        return 0;
    }
    return $count;
}, 10, 2 );

// ─────────────────────────────────────────────────────────────────────────────

add_action( 'wp_enqueue_scripts', function () {
    wp_enqueue_style(
        'twentyten-style',
        get_template_directory_uri() . '/style.css'
    );
    wp_enqueue_style(
        'eckbauer-style',
        get_stylesheet_uri(),
        [ 'twentyten-style' ]
    );
} );
