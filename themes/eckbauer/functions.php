<?php
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
