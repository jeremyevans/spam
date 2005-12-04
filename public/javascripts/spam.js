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

    // We appendChild rows that already exist to the tbody, so it moves them rather than creating new ones
    // don't do sortbottom rows
    for (i=0;i<newRows.length;i++) { if (!newRows[i].className || (newRows[i].className && (newRows[i].className.indexOf('sortbottom') == -1))) table.tBodies[0].appendChild(newRows[i]);}
    // do sortbottom rows only
    for (i=0;i<newRows.length;i++) { if (newRows[i].className && (newRows[i].className.indexOf('sortbottom') != -1)) table.tBodies[0].appendChild(newRows[i]);}
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
    return ts_sort_currency(a,b,6);
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
    $('off_by').innerHTML = ts_displayCurrency(parseCurrency($('balance').innerHTML) + parseCurrency($('reconcile_changes').innerHTML) - parseCurrency($('reconcile_to').value))
}

function updateOffBy(element) {
    var type = element.id.split('_')[0]
    var amount_id = element.id.split('_')[1]
    var amount = parseCurrency($('amount_'+ amount_id).innerHTML)
    if(type == 'debit' ^ element.checked) { amount *= -1; }
    $('reconcile_changes').innerHTML = ts_displayCurrency(parseCurrency($('reconcile_changes').innerHTML) + amount)
    updatedReconcileTo()
}

Ajax.EntityAutocompleter = Class.create();
Object.extend(Object.extend(Ajax.EntityAutocompleter.prototype, Ajax.Autocompleter.prototype), { 
  selectEntry: function() {
    this.active = false;
    this.updateElement(this.getCurrentEntry());
    this.element.focus();
    new Ajax.Request('/update/other_account_for_entry?entity='+this.element.value.replace(/&/g, '%26'), {asynchronous:true, evalScripts:true, onComplete:function(request){eval(request.responseText)}})
  }
});
