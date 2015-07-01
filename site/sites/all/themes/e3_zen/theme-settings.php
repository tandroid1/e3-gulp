<?php
/**
 * Implements hook_form_system_theme_settings_alter().
 *
 * @param $form
 *   Nested array of form elements that comprise the form.
 * @param $form_state
 *   A keyed array containing the current state of the form.
 */
function e3_zen_form_system_theme_settings_alter(&$form, &$form_state, $form_id = NULL)  {
  // Add a setting for selectivizr.
  $form['support']['zen_html5_respond_meta']['#options']['selectivizr'] = t('Add Selectivizr.js file to add support for advanced CSS3 selectors. Be sure to check !selectivizr_website for what selectors are supported in jQuery', array(
      '!selectivizr_website' => l('selectivizr.com', 'http://selectivizr.com/', array(
        'attributes' => array('target' => '_blank'),
      )),
    ));
}
