$(document).ready(function() {
$("#one").fadeIn("normal", function(){
  $("#two").fadeIn("normal", function(){
    $("#three").css({display:'block'}).animate({top:'190px', opacity:'1'},350, function(){
      $("#four").css({display:'block'}).animate({bottom:'29px', opacity:'1'},300);
    });
  });
});
});