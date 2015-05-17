
$(document).ready(function() {
  return $("h2").each(function(i, el) {
    var id = $(el.parentNode).attr('id');
    if (id) {
      var link = $("<a />");
      link.addClass("section-link");
      link.attr("href", "#" + id);
      link.text('¶')
      return $(el).append(link);
    }
  });
});
