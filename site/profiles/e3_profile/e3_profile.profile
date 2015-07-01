<?php
/**
 * @file
 * Enables modules and site configuration for a standard site installation.
 */

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function e3_profile_form_install_configure_form_alter(&$form, $form_state) {
  // Pre-populate the site name with the server name.
  $form['site_information']['site_name']['#default_value'] = $_SERVER['SERVER_NAME'];
  // Set site email address
  $form['site_information']['site_mail']['#default_value'] = 'admin@elevatedthird.com';
  // Set user 1 name
  $form['admin_account']['account']['name']['#default_value'] = 'root';
  // Set user 1 email address
  $form['admin_account']['account']['mail']['#default_value'] = 'admin@elevatedthird.com';
  // Set the default country
  $form['server_settings']['site_default_country']['#default_value'] = 'US';
}
