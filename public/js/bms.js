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

function getImages(repo) {
  $.ajax({
    type: 'GET',
    dataType: 'json',
    url: '/labels/images',
    data: {repo: repo},
    success: function(data) {
      $('#repo-btn').html(repo);
      $('#image-btn').html('Select an image');
      $('#image-dropdown').empty();
      $('#tag-dropdown').empty();
      $.each(data, function(idx, image) {
        $('#image-dropdown').append($('<a></a>').attr('href', 'javascript:getTags("'+repo+'", "'+image+'")').attr('class', 'dropdown-item').text(image));
      });
    },
    error: function(data) {
      alert('Error: ' + data);
    }
  })
}

function getTags(repo, image) {
  $.ajax({
    type: 'GET',
    dataType: 'json',
    url: '/labels/tags',
    data: {repo: repo, image: image},
    success: function(data) {
      $('#image-btn').html(image);
      $('#tag-btn').html('Select a tag');
      $('#tags-dropdown').empty();
      $.each(data, function(idx, tag) {
        $('#tags-dropdown').append($('<a></a>').attr('href', 'javascript:getLabels("'+repo+'", "'+image+'", "'+tag+'")').attr('class', 'dropdown-item').text(tag));
      });
    },
    error: function(data) {
      alert('Error: ' + data);
    }
  })
}

function getLabels(repo, image, tag) {
  $.ajax({
    type: 'GET',
    dataType: 'html',
    url: '/labels/labels',
    data: {repo: repo, image: image, tag: tag},
    success: function(data) {
      $('#tag-text').text(tag);
      $('#label-output').html(data);
    },
    error: function(xhr, textStatus, error) {
      alert('Error: ' + textStatus);
    }
  })
}

function clrRepos() {
  $('#repo-prod').removeClass('active');
  $('#repo-stage').removeClass('active');
  $('#repo-dev').removeClass('active');
}

function changeRepo(tier) {
  clrRepos();
  $('#repo-' + tier).addClass('active');
}
