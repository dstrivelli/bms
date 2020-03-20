function sendEmail(id) {
  var data = { id: id };
  var to = $('#emailModalAddress').val();
  if (to) {
    data['to'] = to;
  }

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
  hideAndClearEmailModal();
  document.getElementById('flashes').innerHTML = data;
}

function processEmailError(xhr, status, error) {
  console.log('executing processEmailError');
  console.log(xhr);
  hideAndClearEmailModal();
  document.getElementById('flashes').innerHTML = xhr.responseText;
}

function getTags(image) {
  $.ajax({
    type: 'GET',
    dataType: 'json',
    url: '/labels/tags',
    data: {image: image},
    success: function(data) {
      $('#image-text').text(image);
      $('#tag-text').text('Select a tag');
      $('#tags-dropdown').empty();
      $.each(data, function(idx, tag) {
        $('#tags-dropdown').append($('<a></a>').attr('href', 'javascript:getLabels("'+image+'", "'+tag+'")').attr('class', 'dropdown-item').text(tag));
      });
    },
    error: function(data) {
      alert('Error: ' + data);
    }
  })
}

function getLabels(image, tag) {
  $.ajax({
    type: 'GET',
    dataType: 'html',
    url: '/labels/labels',
    data: {image: image, tag: tag},
    success: function(data) {
      $('#tag-text').text(tag);
      $('#label-output').html(data);
    },
    error: function(xhr, textStatus, error) {
      alert('Error: ' + textStatus);
    }
  })
}
