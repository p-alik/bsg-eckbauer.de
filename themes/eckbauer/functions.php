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

// ── Per-comment hide — toggled in admin, hidden from guests on frontend ────────

add_action( 'add_meta_boxes_comment', function ( $comment ) {
    add_meta_box(
        'eckbauer_comment_hidden',
        __( 'Sichtbarkeit', 'eckbauer' ),
        function ( $comment ) {
            $is_hidden = get_comment_meta( $comment->comment_ID, '_comment_hidden', true ) === '1';
            wp_nonce_field( 'eckbauer_comment_hidden_' . $comment->comment_ID, 'eckbauer_hidden_nonce' );
            ?>
            <p>
                <label>
                    <input type="checkbox" name="eckbauer_comment_hidden" value="1" <?php checked( $is_hidden ); ?> />
                    <?php esc_html_e( 'Für Gäste ausblenden', 'eckbauer' ); ?>
                </label>
            </p>
            <?php
        },
        'comment',
        'normal'
    );
} );

add_action( 'edit_comment', function ( $comment_id ) {
    if ( ! isset( $_POST['eckbauer_hidden_nonce'] ) ) {
        return;
    }
    if ( ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['eckbauer_hidden_nonce'] ) ), 'eckbauer_comment_hidden_' . $comment_id ) ) {
        return;
    }
    if ( ! current_user_can( 'moderate_comments' ) ) {
        return;
    }
    if ( ! empty( $_POST['eckbauer_comment_hidden'] ) ) {
        update_comment_meta( $comment_id, '_comment_hidden', '1' );
    } else {
        delete_comment_meta( $comment_id, '_comment_hidden' );
    }

    // Flush the post's WP-Optimize page cache so guests see the updated visibility.
    $comment = get_comment( $comment_id );
    if ( $comment && class_exists( 'WPO_Page_Cache' ) ) {
        WPO_Page_Cache::delete_single_post_cache( $comment->comment_post_ID );
    }
} );

// Inject "Für Gäste ausblenden" checkbox into the admin "Kommentar hinzufügen" form.
add_action( 'admin_footer', function () {
    $screen = get_current_screen();
    if ( ! $screen || $screen->base !== 'post' || ! current_user_can( 'moderate_comments' ) ) {
        return;
    }
    ?>
<script>
(function () {
    var nonce = <?php echo wp_json_encode( wp_create_nonce( 'eckbauer_new_comment_hidden' ) ); ?>;
    var label = <?php echo wp_json_encode( __( 'Für Gäste ausblenden', 'eckbauer' ) ); ?>;

    function injectCheckbox() {
        var replyrow = document.getElementById('replyrow');
        if (!replyrow || replyrow.querySelector('.eckbauer-hidden-cb')) return;
        var p = document.createElement('p');
        p.className = 'eckbauer-hidden-cb';
        p.innerHTML = '<label style="font-weight:normal">'
            + '<input type="checkbox" name="eckbauer_comment_hidden" value="1"> '
            + label + '</label>'
            + '<input type="hidden" name="eckbauer_new_hidden_nonce" value="' + nonce + '">';
        var submit = document.getElementById('replysubmit');
        if (submit) {
            submit.parentNode.insertBefore(p, submit);
        }
    }

    document.addEventListener('DOMContentLoaded', injectCheckbox);
})();
</script>
    <?php
} );

add_action( 'comment_post', function ( $comment_id ) {
    if ( empty( $_POST['eckbauer_new_hidden_nonce'] ) ) {
        return;
    }
    if ( ! wp_verify_nonce( sanitize_text_field( wp_unslash( $_POST['eckbauer_new_hidden_nonce'] ) ), 'eckbauer_new_comment_hidden' ) ) {
        return;
    }
    if ( ! current_user_can( 'moderate_comments' ) || empty( $_POST['eckbauer_comment_hidden'] ) ) {
        return;
    }
    update_comment_meta( $comment_id, '_comment_hidden', '1' );
} );

// For guests: replace hidden comment text with a notice; moderators see the original text.
add_filter( 'comment_text', function ( $text, $comment ) {
    if ( ! $comment instanceof WP_Comment ) {
        return $text;
    }
    if ( get_comment_meta( (int) $comment->comment_ID, '_comment_hidden', true ) !== '1' ) {
        return $text;
    }
    if ( current_user_can( 'moderate_comments' ) ) {
        return $text;
    }
    return '<p class="comment-members-only">'
        . esc_html__( 'Dieser Kommentar ist nur für angemeldete Vereinsmitglieder sichtbar', 'eckbauer' )
        . '</p>';
}, 10, 2 );

add_filter( 'comment_class', function ( $classes, $class, $comment_id ) {
    if ( get_comment_meta( $comment_id, '_comment_hidden', true ) !== '1' ) {
        return $classes;
    }
    $classes[] = current_user_can( 'moderate_comments' )
        ? 'comment-hidden-by-admin'
        : 'comment-members-only-view';
    return $classes;
}, 10, 3 );

// ─────────────────────────────────────────────────────────────────────────────

add_action( 'wp_enqueue_scripts', function () {
    wp_enqueue_style(
        'twentyten-style',
        get_template_directory_uri() . '/style.css'
    );
    wp_enqueue_style(
        'eckbauer-style',
        get_stylesheet_uri(),
        [ 'twentyten-style' ],
        wp_get_theme()->get( 'Version' )
    );
} );
