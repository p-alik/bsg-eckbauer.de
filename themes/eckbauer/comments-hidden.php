<?php
// Shown to guests on posts where comments are restricted to logged-in users.
?>
<div id="comments" class="comments-hidden-notice">
    <p><?php esc_html_e( 'Kommentare sind nur für angemeldete Benutzer sichtbar.', 'eckbauer' ); ?>
    <a href="<?php echo esc_url( wp_login_url( get_permalink() ) ); ?>"><?php esc_html_e( 'Anmelden', 'eckbauer' ); ?></a></p>
</div>
