function resetLabelsForm() {
  $('.hide-me').each(function(i) {
    $(this).addClass('d-none').removeClass('d-all');
  });
  $('#imageSelect').empty();
  $('#tagSelect').empty();
  $('#labelCardText').empty();
}

function disableAll() {
  $('#repoSelect').prop('disabled', true);
  $('#imageSelect').prop('disabled', true);
  $('#tagSelect').prop('disabled', true);
}

function enableAll() {
  $('#repoSelect').prop('disabled', false);
  $('#imageSelect').prop('disabled', false);
  $('#tagSelect').prop('disabled', false);
}

function hideMe() {
  $('.hide-me').each(function(i) {
    $(this).addClass('d-none').removeClass('d-all');
  });
}

function getImages() {
  repo = $('#repoSelect option:selected').text();

  $('#repoSelect #blankSelect').remove();
  hideMe();
  disableAll();

  $.ajax({
    type: 'GET',
    dataType: 'json',
    url: '/labels/images',
    data: {repo: repo},
    success: function(data) {
      enableAll();
      $('#imageSelect').empty();
      $('#tagSelect').empty();
      $('#imageSelect').append($('<option></option>').prop('disabled', true).prop('selected', true));
      $.each(data, function(idx, image) {
        $('#imageSelect').append($('<option></option>').text(image));
      });
      $('#imageRow').addClass('d-all').removeClass('d-none');
    },
    error: function(data) {
      alert('Error: ' + data);
      enableAll();
    }
  })
}

function getTags() {
  repo = $('#repoSelect option:selected').text();
  image = $('#imageSelect option:selected').text();

  $('#imageSelect #blankSelect').remove();
  disableAll();
  $('#labelRow').addClass('d-none').removeClass('d-all');

  $.ajax({
    type: 'GET',
    dataType: 'json',
    url: '/labels/tags',
    data: {repo: repo, image: image},
    success: function(data) {
      enableAll();
      $('#tagSelect').empty();
      $('#tagSelect').append($('<option></option>').prop('disabled', true).prop('selected', true));
      $.each(data, function(idx, tag) {
        $('#tagSelect').append($('<option></option>').text(tag));
      });
      $('#tagRow').addClass('d-all').removeClass('d-none');
    },
    error: function(data) {
      alert('Error: ' + data);
      enableAll();
    }
  });
}

function getLabels() {
  repo = $('#repoSelect option:selected').text();
  image = $('#imageSelect option:selected').text();
  tag = $('#tagSelect option:selected').text();

  $('#repoSelect #blankSelect').remove();
  $('#imageSelect #blankSelect').remove();
  $('#tagSelect #blankSelect').remove();
  disableAll();

  $.ajax({
    type: 'GET',
    dataType: 'html',
    url: '/labels/labels',
    data: {repo: repo, image: image, tag: tag},
    success: function(data) {
      enableAll();
      $('#labelCardText').empty();
      $.each(JSON.parse(data), function(key, val) {
        $('#labelCardText').append($('<p></p>').text(key + ": " + val));
      });
      $('#labelRow').addClass('d-all').removeClass('d-none');
    },
    error: function(xhr, textStatus, error) {
      alert('Error: ' + textStatus);
      enableAll();
    }
  });
}
