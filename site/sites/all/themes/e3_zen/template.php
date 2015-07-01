<?php
/**
 * @file
 * Contains the theme's functions to manipulate Drupal's default markup.
 *
 */

/**
 * Override or insert variables into the page templates.
 *
 * @param $variables
 *   An array of variables to pass to the theme template.
 * @param $hook
 *   The name of the template being rendered ("page" in this case.)
 */
/* -- Delete this line if you want to use this function
function e3_zen_preprocess_page(&$variables, $hook) {
  drupal_add_js(drupal_get_path('theme', 'e3_zen') .'/js/utils.js', array(
      'scope' => 'footer'
  ));
}
// */

function e3_zen_preprocess_html(&$variables) {
  //if context_layouts module exist, append active layout class to body
  if(module_exists('context_layouts') && ($layout = context_layouts_get_active_layout())) {
    $variables['classes_array'][] = drupal_html_class('layout-'.$layout['layout']);
  } 

  $html5_respond_meta = theme_get_setting('zen_html5_respond_meta');

  // Add selectivizr.js based on theme settings.
  if (isset($html5_respond_meta['selectivizr']) && $html5_respond_meta['selectivizr']) {
    drupal_add_js(drupal_get_path('theme', 'e3_zen') . '/js/selectivizr-min.js', array(
      'group' => JS_THEME,
    ));
  }
}

/**
 * Override or insert variables into the block templates.
 *
 * @param $variables
 *   An array of variables to pass to the theme template.
 * @param $hook
 *   The name of the template being rendered ("block" in this case.)
 */
function e3_zen_preprocess_block(&$variables) {
  // Shortcut variables
  $block = $variables['block'];
  $templates = &$variables['theme_hook_suggestions'];
  $attributes = &$variables['attributes_array'];

  // Adds an HTML5 template suggestion for modules that render
  // blocks containing menu items.
  $menu_modules = array('menu', 'menu_block', 'nice_menus');
  if (in_array($block->module, $menu_modules)) {
    $templates[] = 'block__nav';

    // Adds navigation role if one doesn't already exist
    if (!array_key_exists('role', $attributes)) {
      $attributes['role'] = 'navigation';
    }
  }
}

/**
 * Implements theme_preprocess_menu_block_wrapper()
 *
 * @param $variables
 *   An array of variables to pass to the theme template.
 * @param $hook
 *   The name of the template being rendered ("menu block" in this case.)
 */
function e3_zen_preprocess_menu_block_wrapper(&$variables) {
  // Add back Drupal's expected .menu to the <ul>
  $variables['classes_array'][] = 'menu';
}

/**
 * Override of theme_menu_tree()
 * We strip out the wrapping UL for menus rendered
 * with Menu Block module. The menu-block-wrapper.tpl.php
 * adds back in the <ul> as a wrapper in our theme. This 
 * provides the added benefit of being able to preprocess
 * the <ul> later on.
 */
function e3_zen_menu_tree__menu_block($variables) {
  return $variables['tree'];
}

/**
 * Override of theme_menu_link()
 * Due to the overrides in e3_zen_menu_tree__menu_block() we 
 * need to add a wrapper for nested menu items.
 *
 * @todo
 *   Create a variable to allow for preprocessing the classes
 *   of nested menus.
 */
function e3_zen_menu_link__menu_block($variables) {
  $element = $variables['element'];
  $sub_menu = '';

  if ($element['#below']) {
    $sub_menu = '<ul class="expanded-child">' . drupal_render($element['#below']) . '</ul>';
  }
  $output = l($element['#title'], $element['#href'], $element['#localized_options']);
  return '<li' . drupal_attributes($element['#attributes']) . '>' . $output . $sub_menu . "</li>\n";
}