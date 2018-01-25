DS.displayPasswordStrength = function (strengthBarId, score) {
  var $bar = $('#' + strengthBarId);
  $bar.removeClass('strength-1 strength-2 strength-3 strength-4');
  if (score > 0) {
    $bar.addClass('strength-' + score);
  }

  var percentage = score * 25
  $bar.text("complexité de " + percentage  + "%");
};

DS.checkPasswordStrength = function (event, strengthBarId, submitButtonId) {
  var $target = $(event.target);
  var password = $target.val();
  if (password.length > 2) {
    $.post('/admin/activate/strength', { password: password }, function(data){
      DS.displayPasswordStrength(strengthBarId, data.score);
    });
  } else {
    DS.displayPasswordStrength(strengthBarId, 0);
  }
};
