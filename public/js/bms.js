$(document).ready(function() {
  $('#scrollspy ul li a[href^="#"]').on('click', function(e) {
    e.preventDefault();
    var hash = e.target.hash;
    var offset = 0;
    if (hash != '') {
      var offset = $(hash).offset().top
    }
    $('html, body').animate({
      scrollTop: offset
    }, 750, function(){
      window.location.hash = hash;
    });
  });
    
  loadLogsFromStorage();
  setBellIcon();
});

/* NOTIFICATIONS */
function loadLogsFromStorage(){
  // Grabs logs from localStorage and puts them into logger on load
  elem = $('#logModalText');
  if (elem == null) { return }
  storedLogs = localStorage.getItem('logHTML');
  if (storedLogs == null) { return }
  else { elem.html(storedLogs); }
}

function setBellIcon() {
  target = $('#icon-notifications');

  if (target == null) {
    return;
  }

  if (Notification.permission === 'denied' || Notification.permission === 'default') {
    target.removeClass('fa-bell').addClass('fa-bell-slash');
    return false;
  } else {
    target.removeClass('fa-bell-slash').addClass('fa-bell');
    return true;
  }
}

function checkNotificationPromise() {
  try {
    Notification.requestPermission().then();
  } catch(e) {
    return false;
  }
  return true;
}

function enableNotifications() {
  // Skip if we are already granted permission
  if (Notification.permission === 'granted') { return }

  // function to actually ask the permissions
  if (!('Notification' in window)) {
    console.log('This browser does not support notifications.');
  } else {
    if(checkNotificationPromise()) {
      Notification.requestPermission()
      .then((permission) => {
        setBellIcon();
      })
    } else {
      Notification.requestPermission(function(permission) {
        handlePermission(permission);
      });
    }
  }
}

function log(text = '', { icon, notify } = { icon: null, notify: true }) {
  // Find the log elem
  elem = $('#logModalText')
  if (elem == null) { return }

  // Notify if enabled
  if (Notification.permission === 'granted' && notify == true) {
    if (icon != null) { icon = '/img/' + icon }
    var notification = new Notification('BMS', { body: text, icon: icon });
  }

  // Add date
  var d = new Date();
  text = d.toLocaleString() + ' : ' + text + "\n";

  if (elem.text() != '') { text = '<br />' + text }
  elem.append(text);
  
  // After adding new item, send new HTML to localStorage
  localStorage.setItem('logHTML', elem.html());
  
  // Scroll log
  elem.scrollTop(elem[0].scrollHeight - elem[0].clientHeight);
}

/* HEALTH UPDATING */
function changeBadgeClass(target, newClass) {
  filter = [
    'badge-danger',
    'badge-success',
    'badge-warning'
  ]
  target.removeClass(filter).addClass(newClass);
}

function bindBadgeToWebSocket(badge, ws) {
  ws.onopen = function(event) {
    changeBadgeClass(badge, 'badge-success');
    log('Monitoring websocket opened connection.', { notify: false });
  };
  ws.onerror = function(event) {
    changeBadgeClass(badge, 'badge-warning');
    badge.attr('title', event);
    console.log("WS Error:" + event);
    log("Monitoring websocket experienced an error. Check Console.log for more details.", { notify: false });
  }
  ws.onclose = function(event) {
    changeBadgeClass(badge, 'badge-danger');
    log("Monitoring websocket closed connection.", { notify: false});
  }
}

function startMonitor(url, badge) {
  console.log('Monitor started for url: ' + url + ' binding to badge: #' + badge.attr('id'));
  //websocket = new WebSocket("wss://bms-api.prod8.bip.va.gov/namespaces/ws");
  websocket = new ReconnectingWebSocket(url);
  changeBadgeClass(badge, 'badge-warning');
  bindBadgeToWebSocket(badge, websocket);
  websocket.onmessage = handleHealthEvent;
}

function handleHealthEvent(event) {
  console.log(event.data);

  // Parse incoming object
  obj = JSON.parse(event.data);
  if (obj == null) {
    console.log('Failed to parse event json.');
    return;
  }

  // Get the target elem
  targetName = '#' + obj.kind + '-' + obj.name;
  target = $(targetName);
  if (target.length == 0) {
    console.log('The object [' + targetName + '] could not be found.');
    return;
  }

  // Compare the new health to our current health. (clears up spam...hopefully)
  console.log(targetName + ' has data-healthy=' + target.attr('data-healthy') + ' and new healthy value is ' + obj.healthy);
  if (target.attr('data-healthy') === obj.healthy) { return }

  // Process health
  var newClass = '';
  var logitem = '';
  var icon = '';
  var titleText = '';
  switch(obj.healthy) {
    case 'True':
      newClass = 'badge-success';
      logitem = '[' + obj.kind + '] ' + obj.name + ' has gone HEALTHY.';
      icon = 'healthy-true.png';
      break;
    case 'False':
      newClass = 'badge-danger';
      logitem = '[' + obj.kind + '] ' + obj.name + ' has gone UNHEALTHY.';
      icon = 'healthy-false.png';
      break;
    case 'Unknown':
      newClass = 'badge-warning';
      logitem = '[' + obj.kind + '] ' + obj.name + ' has gone UNKNOWN.';
      icon = 'healthy-false.png';
      break;
    default:
      newClass = 'badge-warning';
  }

  // Process errors
  if (obj.errors != null && obj.errors.length > 0) {
    titleText = obj.errors.join("\n");
  }

  // Change elem attr, class, and text
  target.attr('data-healthy', obj.healthy);
  changeBadgeClass(target, newClass);
  if (obj.kind == 'url') { target.text(obj.healthy) }
  target.attr('title', titleText);

  // Send log event
  if (logitem != '') {
    log(logitem, { icon: icon, notify: true });
  }
}
