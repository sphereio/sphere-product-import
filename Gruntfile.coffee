'use strict'

module.exports = (grunt) ->
  # project configuration
  grunt.initConfig
    # load package information
    pkg: grunt.file.readJSON 'package.json'

    meta:
      banner: "/* ===========================================================\n" +
        "# <%= pkg.name %> - v<%= pkg.version %>\n" +
        "# ==============================================================\n" +
        "# Copyright (c) 2013,2014 <%= pkg.author.name %>\n" +
        "# Licensed under the MIT license.\n" +
        "*/\n"

    coffeelint:
      options: grunt.file.readJSON('node_modules/sphere-coffeelint/coffeelint.json')
      default: ['Gruntfile.coffee', 'lib/**/*.coffee', 'test/**/*.coffee']

    clean:
      default: "dist"
      test: "dist-test"

    coffee:
      options:
        bare: true
      default:
        expand: true
        flatten: true
        cwd: "lib"
        src: ["*.coffee"]
        dest: "dist"
        ext: ".js"
      test:
        expand: true
        flatten: true
        cwd: "test"
        src: ["*.spec.coffee"]
        dest: "dist-test"
        ext: ".spec.js"

    concat:
      options:
        banner: "<%= meta.banner %>"
      default:
        expand: true
        flatten: true
        cwd: "lib"
        src: ["*.js"]
        dest: "lib"
        ext: ".js"

    # watching for changes
    watch:
      default:
        files: ["lib/*.coffee"]
        tasks: ["build"]
      test:
        files: ["test/*.coffee"]
        tasks: ["test"]

    shell:
      options:
        stdout: true
        stderr: true
        failOnError: true
      jasmine:
        command: "./node_modules/.bin/jasmine-node --captureExceptions --coffee test"
      publish:
        command: 'npm publish'

    bump:
      options:
        files: ['package.json']
        updateConfigs: ['pkg']
        commit: true
        commitMessage: 'Bump version to %VERSION%'
        commitFiles: ['-a']
        createTag: true
        tagName: 'v%VERSION%'
        tagMessage: 'Version %VERSION%'
        push: true
        pushTo: 'origin'
        gitDescribeOptions: '--tags --always --abbrev=1 --dirty=-d'

  # load plugins that provide the tasks defined in the config
  grunt.loadNpmTasks "grunt-coffeelint"
  grunt.loadNpmTasks "grunt-contrib-clean"
  grunt.loadNpmTasks "grunt-contrib-concat"
  grunt.loadNpmTasks "grunt-contrib-coffee"
  grunt.loadNpmTasks "grunt-contrib-watch"
  grunt.loadNpmTasks "grunt-shell"
  grunt.loadNpmTasks 'grunt-bump'

  # register tasks
  grunt.registerTask "build", ["clean", "coffeelint", "coffee", "concat"]
  grunt.registerTask "test", ["coffeelint", "shell:jasmine"]
  grunt.registerTask 'release', 'Release a new version, push it and publish it', (target) ->
    target = 'patch' unless target
    grunt.task.run "bump-only:#{target}", 'build', 'test', 'bump-commit', 'shell:publish'
