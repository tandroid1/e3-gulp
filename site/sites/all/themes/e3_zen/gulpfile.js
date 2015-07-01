"use strict";

var gulp = require('gulp');
var sass = require('gulp-sass');
var compass = require('gulp-compass');
var livereload = require('gulp-livereload');

gulp.task('sass', function() {
  gulp.src('./sass/*.scss')
    .pipe(compass({
      config_file: './config.rb',
      css: 'css',
      sass: 'sass'
    }))
    .pipe(livereload());
});

gulp.task('watch', function() {
  livereload.listen();
  gulp.watch('./sass/**/*.scss', ['sass']);
});
