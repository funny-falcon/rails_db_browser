function fill_id_with_edit_delete($trs) {
  $trs.find('td[data-column=id] span.actions').html(
      ' <a href="javascript:void(0)" class="edit">edit</a>' // <a href="javascript:void(0)" class="delete">delete</a>'
      );
}

$(function(){
    function get_cells(that) {
      var $td = $(that).closest('td');
      var $tr = $td.closest('tr');
      var table = $td.data('table');
      var id = $td.data('id');
      var $tds = $tr.find('td[data-table='+table+']').not($td);
      return {
        $td: $td,
        $tr: $tr,
        table: table,
        $tds: $tds,
        id: id
      }
    }

    $('td[data-column=id] a.edit').live('click', function(){
      var cells = get_cells(this);
      cells.$tds.each(function(){
        var $textarea = $('<textarea></textarea>');
        var $this = $(this);
        var nil = $this.data('nil');
        $this.data('saved-nil', nil);
        if ( !nil ) {
          var value = $this.attr('data-value');
          $this.attr('data-saved-value', value);
          var lines = value.split(/\n\r|\r\n|\n|\r/);
          var max = 12;
          for(var i=0; i < lines.length; i++) {
            max = Math.max( max, lines[i].length );
          }
          $textarea.attr('rows', Math.max(lines.length + 1, 3));
          $textarea.attr('cols', max + 1);
        } else {
          $textarea.attr('disabled', true);
          $this.attr('data-saved-value', '');
          $textarea.attr('rows', 3);
          $textarea.attr('cols', 13);
        }
        $textarea.val(value);
        var $checkbox = $('<input type="checkbox" name="nil" />');
        $checkbox.attr('checked', !!nil);
        var chbx_id = cells.table + '_' + cells.id + '_' +
                      $(this).data('column') + '_nil';
        $checkbox.attr('id', chbx_id);
        var $label = $('<label>NULL:</label>').attr('for', chbx_id);
        $this.html($textarea).append('<br />').
                append($label).append($checkbox);
      })
      cells.$td.find(".actions").html('<a href="javascript:void(0)" class="save">save</a> <a href="javascript:void(0)" class="cancel">cancel</a>');
    });

    $('td[data-table] input[type=checkbox][name=nil]').live('change', function() {
        var $td = $(this).closest('td');
        var $textarea = $td.find('textarea')
        if ( this.checked ) {
          $td.attr('data-value', $textarea.val());
          $textarea.val('').attr('disabled', true);
          $td.data('nil', true);
        } else {
          $textarea.val($td.attr('data-value')).attr('disabled',false);
          $td.data('nil', false);
        }
    });

    function fill_td_with_value($td, value, nil) {
      if ( value.match(/^\S+$/) ) {
        $td.text(value);
        $td.removeClass('inspect');
      } else {
        if ( nil ) {
          value = 'nil';
          $td.addClass('inspect');
        } else if ( value.match(/^\s*$/) ){
          value = '"'+value+'"';
          $td.addClass('inspect');
        } else {
          $td.removeClass('inspect');
        }
        var $pre = $('<pre></pre>');
        $pre.text(value);
        $td.html($pre);
      }
    }

    $('td .actions a.cancel').live('click', function() {
        var cells = get_cells(this);
        cells.$tds.each(function(){
          var $td = $(this);
          $td.attr('data-value', $td.attr('data-saved-value'));
          $td.data('nil', $td.data('saved-nil'));
          var value = $td.attr('data-value');
          var nil = $td.data('nil');
          fill_td_with_value($td, value, nil);
        });
        fill_id_with_edit_delete(cells.$tr);
    });

    $('td .actions a.save').live('click', function() {
        var cells = get_cells(this);
        var attrs = { "id": cells.id };
        cells.$tds.each(function(){
          var $td = $(this);
          var value = $td.find('input:checkbox[name=nil]').attr('checked') ?
                    "null" : '!'+$td.find('textarea').val();
          attrs[$td.attr('data-column')] = value;
        });
        $.ajax({
            url: ROOT+'/t/'+cells.table,
            dataType: 'json',
            data: {attrs: attrs},
            type: 'post',
            success: function(data) {
              cells.$tds.each(function(){
                var $td = $(this);
                if ( $td.data('column') in data ) {
                  var value = data[$td.data('column')];
                  var nil = value === null;
                  value = value ? value : '';
                  $td.attr('data-value', value);
                  $td.data('nil', nil);
                  fill_td_with_value($td, value, nil);
                }
              });
              fill_id_with_edit_delete(cells.$tr);
            },
            error: function(xhr) {
              var $error = $('#error');
              var $error_mask = $('#error_mask');
              $error.find('.content').html(xhr.responseText);
              
              var docHeight = $(document).height();
              var winHeight = $(window).height();
              var winWidth  = $(window).width();
              
              $error_mask.css({ height: winHeight, width: winWidth});
              $error_mask.show();

              $error.css('display', 'hidden');
              var topleft = ({
                    top: Math.max(winHeight - $error.height(), 0)/2,
                    left: Math.max(winWidth - $error.width(), 0)/2
                  });
              $error.css(topleft);

              $error.show();
            }
        });
    });

    $('#error .close, #error_mask').live('click', function() {
        $('#error').hide();
        $('#error_mask').hide();
    });
});
