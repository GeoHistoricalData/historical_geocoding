
/*
 * Note : spinner is an annimation that plays while loading
 */
 var spinnerOptions = {
    lines: 15, // The number of lines to draw.
    length: 20, // The length of each line.
    width: 15, // The line thickness.
    radius: 50, // The radius of the inner circle.
    corners: 1, // Corner roundness (0..1).
    rotate: 0, // The rotation offset.
    direction: 1, // 1: clockwise, -1: counterclockwise.
    color: '#000', // #rgb or #rrggbb or array of colors.
    speed: 1, // Rounds per second.
    trail: 50, // Afterglow percentage.
    shadow: false, // Whether to render a shadow.
    hwaccel: true, // Whether to use hardware acceleration.
    className: 'spinner', // The CSS class to assign to the spinner.
    zIndex: 2e9, // The z-index (defaults to 2000000000).
    top: '50%', // Top position relative to parent.
    left: '50%' // Left position relative to parent.
  };
  
  
  var spinnerContainer = document.getElementsByTagName('body')[0];
  var spinner = new Spinner(spinnerOptions).spin(spinnerContainer);