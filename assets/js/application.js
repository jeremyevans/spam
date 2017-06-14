function ts_getInnerText(el) {
    if (typeof el == "string") return el;
    if (typeof el == "undefined") { return el };
    if (el.innerText) return el.innerText;    //Not needed but it is faster
    var str = "";
    
    var cs = el.childNodes;
    var l = cs.length;
    for (var i = 0; i < l; i++) {
        switch (cs[i].nodeType) {
            case 1: //ELEMENT_NODE
                str += ts_getInnerText(cs[i]);
                break;
            case 3:    //TEXT_NODE
                str += cs[i].nodeValue;
                break;
        }
    }
    return str;
}

function ts_resortTable() {
    var table = document.getElementById('register');
    if (table.rows.length <= 2) return;
    var firstRow = new Array();
    var newRows = new Array();
    for (i=0;i<table.rows[0].length;i++) { firstRow[i] = table.rows[0][i]; }
    for (j=2;j<table.rows.length;j++) { newRows[j-2] = table.rows[j]; }

    newRows.sort(ts_sort);
    for (i=0;i<newRows.length;i++) { table.tBodies[0].appendChild(newRows[i]);}
    ts_recalculateBalance();
}


function ts_sort_currency(a,b,column) { 
    aa = ts_getInnerText(a.cells[column]).replace(/[^0-9.]/g,'') || '0';
    bb = ts_getInnerText(b.cells[column]).replace(/[^0-9.]/g,'') || '0';
    return parseFloat(bb) - parseFloat(aa);
}

function ts_sort_default(a,b,column) {
    aa = ts_getInnerText(a.cells[column]);
    bb = ts_getInnerText(b.cells[column]);
    if (aa==bb) return 0;
    if (aa<bb) return 1;
    return -1;
}

function ts_sort(a,b) {
    var x = ts_sort_default(a,b,0);
    if (x) return x;
    x = ts_sort_currency(a,b,1);
    if (x) return x;
    x = ts_sort_currency(a,b,6);
    if (x) return x;
    x = ts_sort_default(a,b,2);
    if (x) return x;
    x = ts_sort_default(a,b,3);
    if (x) return x;
    return  ts_sort_default(a,b,4); 
}

function ts_recalculateBalance() {
    var table = document.getElementById('register');
    var balance = ts_balanceForRow(table.rows[1]);
    table.rows[2].cells[7].innerHTML = ts_displayCurrency(balance);
    var amount = ts_amountForRow(table.rows[2]);
    for(i=3;i<table.rows.length;i++) {
        balance -= amount;
        table.rows[i].cells[7].innerHTML = ts_displayCurrency(balance);
        amount = ts_amountForRow(table.rows[i]);
    }
}

function ts_amountForRow(row) {
    return ts_floatForCell(row.cells[6]);
}

function ts_balanceForRow(row) {
    return ts_floatForCell(row.cells[7]);
}

function ts_floatForCell(cell) {
    return parseCurrency(ts_getInnerText(cell));
}

function parseCurrency(value) {
    return parseFloat(value.replace(/[^-0-9.]/g,''));
}

function ts_displayCurrency(amount) {
    var i = parseFloat(amount);
    if(isNaN(i)) { i = 0.00; }
    var minus = '';
    if(i < 0) { minus = '-'; }
    i = Math.abs(i);
    i = parseInt((i + .005) * 100);
    i = i / 100;
    s = new String(i);
    if(s.indexOf('.') < 0) { s += '.00'; }
    if(s.indexOf('.') == (s.length - 2)) { s += '0'; }
    s = '$' + minus + s;
    return s;
}

function updatedReconcileTo() {
    $('#off_by').text(ts_displayCurrency(parseCurrency($('#balance').text()) + parseCurrency($('#reconcile_changes').text()) - parseCurrency($('#reconcile_to').val())))
}

function updateOffBy(element) {
    var type = element.id.split('_')[0]
    var amount_id = element.id.split('_')[1]
    var amount = parseCurrency($('#amount_'+ amount_id).text())
    if(type == 'debit' ^ element.checked) { amount *= -1; }
    $('#reconciled_balance').text(ts_displayCurrency(parseCurrency($('#reconciled_balance').text()) + amount))
    $('#reconcile_changes').text(ts_displayCurrency(parseCurrency($('#reconcile_changes').text()) + amount))
    updatedReconcileTo()
}

function set_entity_autocompleter() {
  var reg_account_id = $('#register_account_id').val();
  $('#entity_name').autocomplete('/update/auto_complete_for_entity_name/' + reg_account_id,
    {
      sortResults: false,
      onFinish: function() {
        $.getJSON('/update/other_account_for_entry/' + reg_account_id,
         {entity: $('#entity_name').val()},
         function(data){
          if(data.account_id){$('#account_id').val(data.account_id)}
          if(data.amount){$('#entry_amount').val(data.amount)}
         });
      }
    }
  );
  document.forms[1].entry_date.focus();
}

function handle_actions(actions) {
  var l = actions.length;
  var i;
  for(i=0; i<l; i++) {
    handle_action(actions[i]);
  }
  $('#entry_date').focus().select()
}

function handle_action(action) {
  switch(action[0]) {
  case 'set_value':
    $(action[1]).val(action[2])
    break;
  case 'replace_html':
    $(action[1]).html(action[2])
    break;
  case 'insert_html':
    $(action[1]).after(action[2])
    break;
  case 'focus':
    $(action[1]).focus()
    break;
  case 'autocompleter':
    set_entity_autocompleter()
    break;
  case 'resort':
    ts_resortTable()
    break;
  default:
    alert('Unhandled action type: ' + action[0]);
  }
}

function setup_register_form() {
  $('#register_form').submit(function() {
    $.ajax({
      type: 'POST',
      url: '/update/add_entry',
      dataType: 'json',
      data: $(this).serialize() + '&' + $('#register_form :submit').attr('name') + '=1',
      success: function(data){
        handle_actions(data);
      }
    });
    return false;
  })

  $(document).on('click', 'a.modify', function() {
    $.getJSON($(this).attr('href'),
    {selected_entry_id: $('#selected_entry_id').val()},
    function(data){
      handle_actions(data);
    });

    return false;
  })

  set_entity_autocompleter() 
  handle_actions([])
}

function setup_reconcile_form() {
  $('#auto_reconcile').click(function() {
    $.getJSON('/update/auto_reconcile',
    $(this.form).serialize().replace(/_csrf=[^\&]+\&/, ''),
    function(data){
      handle_actions(data);
    });
    return false;
  })

  $('#clear_entries').click(function() {
    $.ajax({
      type: 'POST',
      url: '/update/clear_entries',
      dataType: 'json',
      data: $(this.form).serialize(),
      success: function(data){
        handle_actions(data);
      }
    });
    return false;
  })

  document.forms[1].reconcile_to.select();
  document.forms[1].reconcile_to.focus();
}
