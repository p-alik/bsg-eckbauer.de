<?php
/**
 * Header template for our theme
 *
 * Displays all of the <head> section and everything up till <div id="main">.
 *
 * @package WordPress
 * @subpackage Eckbauer
 */
?><!DOCTYPE html>
<html <?php language_attributes(); ?>>
<head>
<meta charset="<?php bloginfo( 'charset' ); ?>" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>
<?php
	global $page, $paged;

	wp_title( '|', true, 'right' );

	bloginfo( 'name' );

	$site_description = get_bloginfo( 'description', 'display' );
if ( $site_description && ( is_home() || is_front_page() ) ) {
	echo " | $site_description";
}

if ( ( $paged >= 2 || $page >= 2 ) && ! is_404() ) {
	/* translators: %s: Page number. */
	echo esc_html( ' | ' . sprintf( __( 'Page %s', 'twentyten' ), max( $paged, $page ) ) );
}

?>
	</title>
<link rel="profile" href="https://gmpg.org/xfn/11" />
<link rel="pingback" href="<?php echo esc_url( get_bloginfo( 'pingback_url' ) ); ?>">
<?php
if ( is_singular() && get_option( 'thread_comments' ) ) {
	wp_enqueue_script( 'comment-reply' );
}
	wp_head();
?>
</head>

<body <?php body_class(); ?>>
<?php wp_body_open(); ?>
<div id="wrapper" class="hfeed">
	<a href="#content" class="screen-reader-text skip-link"><?php _e( 'Skip to content', 'twentyten' ); ?></a>
	<div id="header">
		<div id="masthead">
			<div id="branding" role="banner">
				<?php
				$heading_tag      = ( is_home() || is_front_page() ) ? 'h1' : 'div';
				$is_front         = ! is_paged() && ( is_front_page() || ( is_home() && ( (int) get_option( 'page_for_posts' ) !== get_queried_object_id() ) ) );
				$site_name        = get_bloginfo( 'name', 'display' );
				$site_description = get_bloginfo( 'description', 'display' );

				if ( $site_name ) :
					?>
					<<?php echo $heading_tag; ?> id="site-title">
						<span>
							<a href="<?php echo esc_url( home_url( '/' ) ); ?>" rel="home" <?php echo $is_front ? 'aria-current="page"' : ''; ?>><?php echo $site_name; ?></a>
						</span>
					</<?php echo $heading_tag; ?>>
					<?php
				endif;

				if ( $site_description ) :
					?>
					<div id="site-description"><?php echo $site_description; ?></div>
					<?php
				endif;

				if ( function_exists( 'get_custom_header' ) ) {
					$header_image_width = get_theme_support( 'custom-header', 'width' );
				} else {
					$header_image_width = HEADER_IMAGE_WIDTH;
				}

				$image = false;
				if ( is_singular() && has_post_thumbnail( $post->ID ) ) {
					$image = wp_get_attachment_image_src( get_post_thumbnail_id( $post->ID ), array( $header_image_width, $header_image_width ) );
				}
				if ( $image && $image[1] >= $header_image_width ) {
					echo get_the_post_thumbnail( $post->ID, 'post-thumbnail' );
				} else {
					twentyten_header_image();
				}
				?>
			</div><!-- #branding -->

			<div id="access" role="navigation">
				<button class="menu-toggle" aria-controls="menu-header" aria-expanded="false" aria-label="<?php esc_attr_e( 'Menu', 'twentyten' ); ?>">
					<span class="menu-toggle-bar"></span>
					<span class="menu-toggle-bar"></span>
					<span class="menu-toggle-bar"></span>
				</button>
				<?php
				wp_nav_menu(
					array(
						'container_class' => 'menu-header',
						'theme_location'  => 'primary',
					)
				);
				?>
			</div><!-- #access -->
		</div><!-- #masthead -->
	</div><!-- #header -->

	<div id="main">
