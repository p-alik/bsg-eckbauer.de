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
