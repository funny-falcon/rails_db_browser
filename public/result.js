$(function(){
    $('td[data-column=id] a.edit').live('click', function(){
      var $td = $(this).closest('td');
      var $tr = $td.closest('tr');
      var table = $td.data('table');
      var $tds = $tr.find('td[data-table='+table+']').not($td);
      $tds.each(function(){
        var $textarea = $('<textarea></textarea>');
        var nil = $(this).data('nil');
        if ( !nil ) {
          var value = $(this).attr('data-value');
          var lines = value.split("/\n\r|\r\n|\n|\r/");
          var max = 12;
          for(var i=0; i < lines.length; i++) {
            max = Math.max( max, lines[i].length );
          }
          $textarea.attr('rows', Math.max(lines.length + 1, 3));
          $textarea.attr('cols', max + 1);
        } else {
          $textarea.attr('disabled', true);
        }
        $textarea.val(value);
        var $checkbox = $('<input type="checkbox" name="nil" />');
        $checkbox.attr('checked', !!nil);
        var chbx_id = table + '_' + $(this).data('id') + '_' +
                      $(this).data('column') + '_nil';
        $checkbox.attr('id', chbx_id);
        var $label = $('<label>NULL:</label>').attr('for', chbx_id);
        $(this).html($textarea).append('<br />').
                append($label).append($checkbox);
      })
    });

    $('td[data-table] input[type=checkbox][name=nil]').live('change', function() {
        var $td = $(this).closest('td');
        var $textarea = $td.find('textarea')
        if ( this.checked ) {
          $td.attr('data-value', $textarea.val());
          $textarea.val('').attr('disabled', true);
        } else {
          $textarea.val($td.attr('data-value')).attr('disabled',false);
        }
    });
});
