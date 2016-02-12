$(document).ready(function() {

  var domain = 'https://data.douglas.co.us',
      carouselDatasetId = 'g6yt-853b';

  $.ajax({
    url: domain + '/resource/' + carouselDatasetId + '.json?'
  }).done(function (data) {
    for (var i = 0; i < data.length; i++) {
      /*document.getElementById('carousel-content').innerHTML += '<div class="slick-slide" data-slick-index="' + [i] + '"><div class="image"><img src="' + domain + '/views/' + carouselDatasetId + '/files/' + data[i].image + '" /></div></div>';*/
      document.getElementById('carousel-content').innerHTML += '<div id="slide' + [i] + '" class="slick-slide" data-slick-index="' + [i] + '"></div>';
      $('#slide' + [i]).css('background-image', 'url(' + domain + '/views/' + carouselDatasetId + '/files/' + data[i].image + ')');
      /*document.getElementById('carousel-content').innerHTML += '<img src="' + domain + '/views/' + carouselDatasetId + '/files/' + data[i].image + '" />';*/
    }   

    $('.slick-track').slick({
      dots: false,
      arrows: false,
      infinite: true,
      autoplaySpeed: 5000,
      autoplay: true,
      fade: true,
      cssEase: 'linear'
    });  
  });

});