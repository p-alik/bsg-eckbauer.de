<?php
/**
 * Sidebar – child-theme override.
 * Adds a mobile toggle button before the parent sidebar output.
 */
?>
<button class="sidebar-toggle" aria-controls="primary" aria-expanded="false" aria-label="<?php esc_attr_e( 'Seitenleiste', 'eckbauer' ); ?>">
	<span class="sidebar-toggle-label"><?php esc_html_e( 'Seitenleiste', 'eckbauer' ); ?></span>
	<span class="sidebar-toggle-icon" aria-hidden="true">+</span>
</button>
<?php include get_template_directory() . '/sidebar.php'; ?>
