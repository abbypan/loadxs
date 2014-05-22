<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <title>audio.js</title>
    <script src="/js/jquery.js"></script>
    <script src="/js/audiojs/audio.min.js"></script>
    <link rel="stylesheet" href="/js/audiojs/index.css" media="screen">
<script>
function get_shuffle_song() {
    var song_num = $('ol li').size();
    var rand_num = Math.floor(Math.random()*song_num);
    var    song = $('ol li').eq(rand_num);
    return song;
}

function get_next_song() {
        var next = $('li.playing').next();
        if (!next.length) next = $('ol li').first();
        return next;
}

function get_prev_song() {
        var prev =  $('li.playing').prev();
        if (!prev.length) prev = $('ol li').last();
        return prev;
}

function select_new_song(type) {
    var is_shuffle = $('#shuffle').attr('checked');
    var song = is_shuffle ? get_shuffle_song() :
(type == 'next') ? get_next_song() :   // right arrow
(type == 'prev') ? get_prev_song() : null;    // left arrow
    return song;
}

function play_song(audio, next){
    next.addClass('playing').siblings().removeClass('playing');
    audio.load($('a', next).attr('data-src'));
    $('title').html(next.text());
    $('.track-details').html(next.text());
    audio.play();
}

function init_song_list() {
    var music_str = $('#music_data').html();
    var music_data = JSON.parse(music_str);
    var items = [];
    $.each(music_data, function(i, s) {
        items.push('<li><a href="#" data-src="' + s.url + '">' + s.artist +'-' + s.title + ','+ s.kbps + 'kpbs' + '</a></li>');
    });

    $('<ol/>', { html: items.join('') }).appendTo('#wrapper');
}
</script>
</head>
<body>
<div id="wrapper">
    <h1><em>喜欢的音乐 [% time %]</em></h1>
    <p>键盘快捷键：
    <em>&rarr;</em> 前 ,
    <em>&larr;</em> 后 ,
    <em>Space</em>  暂停
    </p>

    <p>PC在线播放需配置下列站点：</p>
    <ul>
        <li>zhangmenshiting.baidu.com</li>
        <li>file.qianqian.com</li>
    </ul>
    <p>
    的referer为http://music.baidu.com，
    <a href="firefox-refcontrol-music.png">firefox</a>、<a href="chrome-redirector-music.png">chrome</a> 
    </p>

    <p><input type="checkbox" name="shuffle" id="shuffle" checked>随机播放</p>

    <audio preload></audio>
    <div class="track-details"></div>
    <p></p>
</div>

<!--<div id="shortcuts">-->
<!--<h1>键盘快捷键</h1>-->
<!--<p><em>&rarr;</em> 下一首 </p>-->
<!--<p><em>&larr;</em> 上一首 </p>-->
<!--<p><em>Space</em>  暂停 </p>-->
<!--</div>-->

<script>

$(document).ready( function() {
    init_song_list();

    // Setup the player to autoplay the next track
    var a = audiojs.createAll({
        trackEnded: function() {
            var next = select_new_song('next');
            play_song(audio,next);
        }
    });

    // Load in the first track
    var audio = a[0];
    play_song(audio, $('ol li').first());
//    first = $('ol a').attr('data-src');
 //   $('ol li').first().addClass('playing');
  //  audio.load(first);

    // Load in a track on click
    $('ol li').click(function(e) {
        e.preventDefault();
        play_song(audio,$(this));
    });

    // Keyboard shortcuts
    $(document).keydown(function(e) {
        var unicode = e.charCode ? e.charCode : e.keyCode;
        if (unicode == 32) {
            audio.playPause();
        }else{
        var t = (unicode == 39) ? 'next' :   // right arrow
                (unicode == 37) ? 'prev' : null;    // left arrow
                if(t){
                var song = select_new_song(t);
                song.click();
                }
        }
    })
});

</script>

<div id="music_data" style="display:none;">
<%= $_[0] %>
</div>


</body>
</html>
