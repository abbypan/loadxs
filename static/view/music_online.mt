<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>audio.js</title>
    <script src="/js/jquery.js"></script>
    <script src="/js/audiojs/audio.min.js"></script>
    <link rel="stylesheet" href="/js/audiojs/index.css" media="screen">
<script>
//read music info
$(document).ready( function() {

var music_str = $('#music_data').html();
var music_data = JSON.parse(music_str);
var items = [];
$.each(music_data, function(i, s) {
    items.push('<li><a href="#" data-src="' + s.url + '">' + s.artist +'-' + s.title + ','+ s.kbps + 'kpbs' + '</a></li>');
    });

$('<ol/>', { html: items.join('') }).appendTo('#wrapper');

      $(function() { 
        // Setup the player to autoplay the next track
        var a = audiojs.createAll({
          trackEnded: function() {
            var next = $('ol li.playing').next();
            if (!next.length) next = $('ol li').first();
            next.addClass('playing').siblings().removeClass('playing');
            audio.load($('a', next).attr('data-src'));
            audio.play();
          }
        });
        
        // Load in the first track
        var audio = a[0];
            first = $('ol a').attr('data-src');
        $('ol li').first().addClass('playing');
        audio.load(first);

        // Load in a track on click
        $('ol li').click(function(e) {
          e.preventDefault();
          $(this).addClass('playing').siblings().removeClass('playing');
          audio.load($('a', this).attr('data-src'));
          audio.play();
        });
        // Keyboard shortcuts
        $(document).keydown(function(e) {
          var unicode = e.charCode ? e.charCode : e.keyCode;
             // right arrow
          if (unicode == 39) {
            var next = $('li.playing').next();
            if (!next.length) next = $('ol li').first();
            next.click();
            // back arrow
          } else if (unicode == 37) {
            var prev = $('li.playing').prev();
            if (!prev.length) prev = $('ol li').last();
            prev.click();
            // spacebar
          } else if (unicode == 32) {
            audio.playPause();
          }
        })
      });

});
    </script>
  </head>
  <body>
<div id="music_data" style="display:none;">
<%= $_[0] %>
</div>
  <div id="wrapper">
      <h1><em>百度音乐</em></h1>
      <audio preload></audio>
  </div>

  <div id="shortcuts">
      <div>
          <h1>键盘快捷键</h1>
          <p><em>&rarr;</em> 下一首 </p>
          <p><em>&larr;</em> 上一首 </p>
          <p><em>Space</em>  暂停 </p>
      </div>
  </div>
  </body>
  </html>
