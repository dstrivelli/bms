$('#scrollspy ul li a[href^="#"').on('click', function(e) {
  e.preventDefault();
  var hash this.hash;
  $('html, body').animate({
    scrollTop: $(this.hash).offset().top
  }, 1000, function(){
    window.location.hash = hash;
  });
});

function sendEmail(id) {
  var data = { id: id };
  var to = $('#emailModalAddress').val();
  if (to) {
    data['to'] = to;
  }

  hideAndClearEmailModal();

  $.ajax({
    type: 'POST',
    dataType: 'html',
    url: '/reports/email',
    data: data,
    success: processEmailSuccess,
    error: processEmailError
  });
}

function hideAndClearEmailModal() {
  console.log('executing hideAndClearEmailModal');
  $('#emailModal').modal('hide');
  $('#emailModalAddress').val('');
}

function processEmailSuccess(data) {
  console.log('executing processEmailsuccess');
  console.log(data);
  document.getElementById('flashes').innerHTML = data;
}

function processEmailError(xhr, status, error) {
  console.log('executing processEmailError');
  console.log(xhr);
  document.getElementById('flashes').innerHTML = xhr.responseText;
}
