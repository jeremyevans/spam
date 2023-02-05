window.addEventListener("load", function() {
  var t = 0;
  var f = document.getElementById("account_filter");
  var cfs = Array.from(document.getElementsByClassName("column_filter"));
  var trs = Array.from(document.getElementsByClassName("account"));
  var name_tds = Array.from(document.getElementsByClassName("account_name"));

  f.addEventListener("keydown", function() {
     if (t) {
       clearTimeout(t);
     } 
     t = setTimeout(filter_accounts, 400);
  });

  cfs.forEach(function(cf) {
    cf.addEventListener("click", filter_accounts);
  });

  function filter_accounts() {
    var v = f.value.toLowerCase();

    trs.forEach(function(tr) {
      tr.classList.remove("hide");
    });

    cfs.forEach(function(cf) {
      if (cf.checked) {
        Array.from(document.getElementsByClassName(cf.id)).forEach(function(td) {
          if (td.classList.contains('empty')) {
            td.parentElement.classList.add('hide');
          }
        });
      }
    });

    name_tds.forEach(function(td) {
      if (td.innerHTML.toLowerCase().indexOf(v) == -1)  {
        td.parentElement.classList.add('hide');
      }
    });

    trs.forEach(function(tr) {
      if (tr.classList.contains('hide')) {
        tr.classList.add("hidden");
      } else {
        tr.classList.remove("hidden");
      }
    });
  }
}, false);
