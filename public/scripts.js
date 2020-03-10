$(document).ready(function() {
  $('a.timestamp').each(function(){
    var epoch = $(this).attr('time');
    d = new Date(0);
    d.setUTCSeconds(epoch);
    this.text = d.toLocaleString("en-US");
  });
});

function process_alert(result) {
  alert(result);
}
