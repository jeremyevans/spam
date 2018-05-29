window.addEventListener("load", function() {
t = 0;
f = $("#account_filter");
cf = $(".column_filter");
tr = $("tr.account");
$(document).ready(function() {
  f.keypress(function() {
   if (t) {
     clearTimeout(t);
   } 
   t = setTimeout(filter_accounts, 400);
  });
  cf.click(function() {
    filter_accounts();   
  });
});

function filter_accounts() {
  var v = f.val().toLowerCase();
  tr.removeClass("hide");
  cf.filter(":checked").each(function() {
    $("td." + $(this).attr("id")).filter("td.empty").parent().addClass("hide");
  });
  tr.filter(function() {
    return $(this).children('td.account_name').html().toLowerCase().indexOf(v) == -1;
  }).addClass("hide");
  tr.filter(function() {
    return !$(this).hasClass("hide");
  }).show();
  tr.filter('tr.hide').hide();
}
}, false);
