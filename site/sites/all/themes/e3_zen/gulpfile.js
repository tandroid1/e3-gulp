"use strict";

var gulp = require('gulp');
var sass = require('gulp-sass');
var compass = require('gulp-compass');

gulp.task('sass', function() {
  gulp.src('./sass/style.scss')
    .pipe(compass({
      config_file: './config.rb',
      css: 'css',
      sass: 'sass'
    }));
});
