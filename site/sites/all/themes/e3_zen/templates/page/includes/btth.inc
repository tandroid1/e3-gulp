<?php if(in_array(1, $btth)): ?>

  <div id="content-btth">
      
      <?php if ($btth['breadcrumb']): ?>
          <?php print $breadcrumb; ?>
      <?php endif; ?>
     
      <a id="main-content"></a> 
      
      <?php if ($btth['title_pref']): ?>
          <?php print render($title_prefix); ?>
      <?php endif; ?>

      <?php if ($title && $btth['title']): ?>
          <h1 class="title" id="page-title"><?php print $title; ?></h1>
      <?php endif; ?>

      <?php if ($btth['title_suf']): ?>
          <?php print render($title_suffix); ?>
      <?php endif; ?>

      <?php if ($btth['messages']): ?>
          <?php print $messages; ?>
      <?php endif; ?>

      <?php if (render($tabs) && $btth['tabs']): ?>
        <div class="tabs"><?php print render($tabs); ?></div>
      <?php endif; ?>

      <?php if ($btth['help']): ?>
          <?php print render($page['help']); ?>
      <?php endif; ?>

      <?php if ($action_links && $btth['action_links']): ?>
         <ul class="action-links"><?php print render($action_links); ?></ul>
      <?php endif; ?>

    </div><!--/#content-btth-->

<?php endif; ?>


