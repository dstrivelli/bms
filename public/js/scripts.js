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

function process_alert(result) {
  alert(result);
}
