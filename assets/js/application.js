(function() {
  var button = document.getElementById('toggle-nav');
  var nav = document.getElementById('bs-example-navbar-collapse-1');
  button.onclick = function(){nav.classList.toggle('display');};

  var details = Array.from(document.querySelectorAll("#bs-example-navbar-collapse-1 details"));
  details.forEach((detail) => {
    detail.onclick = () => {
      details.forEach((d) => {
        if (d !== detail) {
          d.removeAttribute("open");
        }
      });
    };
  });

  Array.from(document.querySelectorAll(".alert-dismissible button")).forEach((button) => {
    button.onclick = () => {
      button.parentElement.remove();
    };
  });
})();

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

function handle_actions(actions) {
  var l = actions.length;
  var i;
  for(i=0; i<l; i++) {
    handle_action(actions[i]);
  }
  var entry_date = document.getElementById('entry_date');
  if (entry_date) {
    entry_date.focus();
    entry_date.select();
  }
}

var serialize = function(obj) {
  var str = [];
  for (var p in obj) {
    if (obj.hasOwnProperty(p)) {
      str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
    }
  }
  return str.join("&");
}

var ajax = function(options){
  var xhr = new XMLHttpRequest();
  xhr.dataType = options.dataType;

  if (options.type !== 'POST') {
    options.type = "GET";
    if (options.data && Object.keys(options.data).length !== 0) {
      options.url += (options.url.includes('?') ? '&' : '?') + options.data;
      options.data = {};
    }
  }

  xhr.open(options.type, options.url);
  for (var name in options.headers){
    xhr.setRequestHeader(name, options.headers[name]);
  }
  if (options.dataType == 'json') {
    xhr.setRequestHeader('Accept', 'application/json');
  }
  if (options.form) {
    if (!options.data) {
      options.data = {};
    }
    var i;
    for (i = 0; i < options.form.length; i++) {
      var elem = options.form[i];
      if (elem.tagName !== 'INPUT' || elem.type !== "checkbox" || elem.checked) {
        options.data[elem.name] = elem.value;
      }
    }
    options.data = serialize(options.data);
  }
  xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

  xhr.onreadystatechange = function(){
    if (xhr.readyState === 4){
      var status = xhr.status;
      if (status >= 200 && status < 300 || status === 304){
        if (options.success) {
          options.success(xhr.responseText);
        }
        else {
          handle_actions(JSON.parse(xhr.responseText));
        }
      } 
    }
  }
  xhr.send(options.data);
  return xhr;
};

function getJSON(url, data) {
  ajax({type: 'GET', url: url, data: serialize(data), dataType: 'json'});
}

var register_form = document.getElementById('register_form');
if (register_form) {
  function set_entity_autocompleter() {
    var reg_account_id = document.getElementById('register_account_id').value;
    new autoComplete({
      selector: '#entity_name',
      minChars: 2,
      source: function(term, suggest) {
        ajax({
          url: ('/update/auto_complete_for_entity_name/' + reg_account_id + '?q=' + encodeURIComponent(term)),
          success: function(body){suggest(body.split("\n"));}
        });
      },
      onSelect: function(ev, term, item) {
        ajax({
          url: ('/update/other_account_for_entry/' + reg_account_id + '?entity=' + encodeURIComponent(document.getElementById('entity_name').value)),
          success: function(body){
            data = JSON.parse(body);
            if(data.account_id) {
              document.getElementById('account_id').value = data.account_id;
            }
            if(data.amount) {
              document.getElementById('entry_amount').value = data.amount;
            }
          }
        });
      }
    });

    register_form.entry_date.focus();
  }

  register_form.onsubmit = function(e) {
    e.preventDefault();
    var data = {}
    data[document.querySelector('#register_form input[type=submit]').getAttribute('name')] = '1';
    ajax({
      type: 'POST',
      url: '/update/add_entry',
      dataType: 'json',
      data: data,
      form: register_form
    });
  };

  register_form.addEventListener('click', (e) => {
    var target = e.target;
    if (target.tagName == 'A' && target.classList.contains('modify')){
      e.preventDefault();
      getJSON(e.target.getAttribute('href'),
        {selected_entry_id: document.getElementById('selected_entry_id').value});
    }
  });

  set_entity_autocompleter() 
  handle_actions([])
}

var reconcile_form = document.getElementById('reconcile_form');
if (reconcile_form) {
  function updatedReconcileTo() {
      document.getElementById('off_by').innerText = ts_displayCurrency(
        parseCurrency(document.getElementById('balance').innerText) +
        parseCurrency(document.getElementById('reconcile_changes').innerText) -
        parseCurrency(document.getElementById('reconcile_to').value)
      );
  }

  function updateOffBy(element) {
    var type = element.id.split('_')[0]
    var amount_id = element.id.split('_')[1]
    var amount = parseCurrency(document.getElementById('amount_'+ amount_id).innerText);
    if(type == 'debit' ^ element.checked) { amount *= -1; }
    var reconciled_balance = document.getElementById('reconciled_balance');
    var reconciled_changes = document.getElementById('reconcile_changes');
    reconciled_balance.innerText = ts_displayCurrency(
      parseCurrency(reconciled_balance.innerText) + amount
    );
    reconcile_changes.innerText = ts_displayCurrency(
      parseCurrency(reconcile_changes.innerText) + amount
    );
    updatedReconcileTo();
  }

  document.getElementById('reconcile_to').onchange = updatedReconcileTo;

  reconcile_form.onchange = function(e) {
    var target = e.target;
    if (target.tagName == 'INPUT' && target.classList.contains('reconcile_checkbox')) {
      updateOffBy(target);
    }
  };

  document.getElementById('auto_reconcile').onclick = function(e) {
    e.preventDefault();
    var i;
    var data = {};
    for (i = 0; i < reconcile_form.length; i++) {
      var elem = reconcile_form[i];
      if (elem.type != 'checkbox' || elem.checked !== false) {
        data[elem.name] = elem.value;
      }
    }
    delete data['_csrf'];
    ajax({type: 'GET', url: '/update/auto_reconcile', data: serialize(data), dataType: 'json'});
  };

  document.getElementById('clear_entries').onclick = function(e) {
    e.preventDefault();
    var i;
    var data = {};
    for (i = 0; i < reconcile_form.length; i++) {
      var elem = reconcile_form[i];
      if (elem.type != 'checkbox' || elem.checked !== false) {
        data[elem.name] = elem.value;
      }
    }
    delete data['auto_reconcile'];
    ajax({type: 'POST', url: '/update/clear_entries', data: serialize(data), dataType: 'json'});
  };

  reconcile_form.reconcile_to.select();
  reconcile_form.reconcile_to.focus();
}

function handle_action(action) {
  switch(action[0]) {
  case 'set_value':
    Array.from(document.querySelectorAll(action[1])).forEach((e) => {e.value = action[2];})
    break;
  case 'replace_html':
    Array.from(document.querySelectorAll(action[1])).forEach((e) => {e.innerHTML = action[2];});
    break;
  case 'insert_html':
    Array.from(document.querySelectorAll(action[1])).forEach((e) => {e.insertAdjacentHTML('afterend',action[2]);});
    break;
  case 'focus':
    document.querySelector(action[1]).focus();
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
