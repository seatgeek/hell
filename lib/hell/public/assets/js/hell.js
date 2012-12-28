$(function() {

  var src = null;

  var ex = _.extend(Backbone.Model.prototype, {

    _errors: {},

    // Convenience function to mass update properties
    // unless they have a value
    setUnless: function(attrs, options) {
      var attr, val;
      options = options || {};

      attrs = attrs && attrs.length ? attrs : this.set_unless;

      for (attr in attrs) {
        if (!this.has(attr)) {
          val = attrs[attr];
          this.set(attr, val, options);
        }
      }
    },

    clearErrors: function() {
      this._errors = {};
    },

    // Return errors for a field or for the model
    getErrors: function(field) {
      if (!field) return this._errors;
      if (_.has(this._errors, field)) return  this._errors[field];
      return undefined;
    },

    // Set an error message for a given field
    setError: function(field, error) {
      this._errors = this._errors || {};
      this._errors[field] = this._errors[field] || [];
      this._errors[field].push(error);
    },

    // Returns whether the current validates call has produced errors
    hasErrors: function() {
      this._errors = this._errors || {};
      var errors = _.reject(this._errors, function(v, k) { return v.length === 0; });
      return errors.length > 0;
    },

    // Custom validation rule
    validates: function(attrs) {
      // Do not require passing in the attributes being checked
      attrs = attrs || this.attributes;

      // Clear all errors before continuing
      this.clearErrors();

      // Run validation
      this._validates(attrs);

      // Trigger `errors` or `validates` events
      var hasErrors = this.hasErrors();
      this.trigger(hasErrors ? 'errors' : 'validates', this, this._errors);
      return !hasErrors;
    },

    _validates: function(attrs) {
      return true;
    }

  });

  var Task = Backbone.Model.extend({

    _status_badge_map: {
      'fail': 'important',
      'pending': 'warning',
      'sent': 'info',
      'success': 'success',
      'finished': 'inverse'
    },

    set_unless: {
      'timestamp': new Date().getTime(),
      'iso_time': new Date(new Date().getTime()).toISOString(),
      'status': 'pending'
    },

    defaults: function() {
      return {
        task_id: null,
        name: null,
        environment: null,
        verbose: true,
        timestamp: null,
        status: null
      };
    },

    initialize: function() {
      this.setUnless({}, {silent: true});
    },

    execute: function() {
      var that = this;
      $('.task-output').empty();

      HellApp.set_flash("Sending execution request", "info");
      HellApp.toggle_overlay();
      var jqxhr = $.ajax({
        url: HellApp.www_base_dir + 'tasks/' + that.command() + '/background?verbose=' + that.get('verbose')
      });

      jqxhr.always(function(data) {
        HellApp.close_sockets(src);
        HellApp.toggle_overlay();
      });

      jqxhr.fail(function(data) {
        HellApp.set_flash("Failure receiving server response");
        that.setStatus("fail");
      });

      jqxhr.done(function(data) {
        HellApp.set_flash("Received ajax response", "info");
        that.set('task_id', data.task_id);
        that.setStatus("sent");
        that.save();

        // Create new websocket
        src = new EventSource(HellApp.www_base_dir + 'logs/' + that.get('task_id') + '/tail');

        // Received the first response
        src.addEventListener('start', function () {
          HellApp.set_flash("Received the first response for " + that.get('name'), "success");
          that.setStatus("started");
        });

        // Close the websocket when there are no more events
        src.addEventListener('end', function () {
          HellApp.set_flash("Received the last response " + that.get('name'), "info");
          that.setStatus("finished");
          HellApp.close_sockets(src);
        });

        // Append the messages to the .task-output div
        src.onmessage = function(e) {
          var message = jQuery.parseJSON(e.data);
          $('.task-output').append(message.message.replace(/~+$/, ''));
          $(".task-output").animate({scrollTop: $(".task-output").prop("scrollHeight")}, 1);
        };
      });
    },

    view: function() {
      HellApp.set_flash("Viewing a past task", "info");

      // Close all websockets
      HellApp.close_sockets(src);
      HellApp.toggle_overlay();
      window.location.hash = "#run";

      var jqxhr = $.ajax({url: HellApp.www_base_dir + 'logs/' + this.get('task_id') + '/view'});
      jqxhr.always(function(data) { HellApp.toggle_overlay(); });
      jqxhr.done(function(data) {
        HellApp.set_flash("Received proper server response", "success");
        $('.task-output').html(data.replace(/~+$/, ''));
        $(".task-output").animate({scrollTop: $(".task-output").prop("scrollHeight")}, 1);
      });
      jqxhr.fail(function(data) { HellApp.set_flash("Failure receiving server response"); });
    },

    // Backbone's built-in validation only allows for a single error
    // per save. Using this method, we can attach multiple error messages
    // to a single field. This will not work for embedded documents
    _validates: function(attrs) {
      // Validate that there is a task
      if (attrs.name === null || attrs.name.length === 0) {
        this.setError('name', 'Please enter a capistrano task');
      }

      // Validate task name in available_commands
      else if ($.inArray(attrs.name, HellApp.tasks) === -1) {
        this.setError('name', 'Capistrano command not in your defined tasks');
      }

      // Validate that an environment is set
      if (HellApp.require_env && attrs.environment === null || attrs.environment.length === 0) {
        this.setError('environment', 'Environment required to run any tasks');
      }

      if (attrs.environment && attrs.environment.length > 0) {
        if ($.inArray(attrs.environment, HellApp.environments) === -1) {
          this.setError('environment', 'Invalid environment ' + attrs.environment + ' specified');
        }
      }
    },

    command: function() {
      var cmd = [ this.get('environment') + ' ', this.get('name') ];
      return _.reject(cmd, function(v) { return v.length === 0; }).join(' ');
    },

    cap_command: function() {
      return [ 'cap', this.command() ].join(' ');
    },

    badge: function() {
      return this._status_badge_map[this.get('status')];
    },

    toFullJSON: function() {
      return _.extend(this.toJSON(), {
        command: this.cap_command(),
        badge: this.badge()
      });
    },

    toRerunJSON: function() {
      var omit = _.keys(this.set_unless);
      omit.push("id");
      return _.omit(this.toJSON(), omit);
    },

    setStatus: function(s) {
      this.save({status: s});
      return this;
    }

  });

  var TaskView = Backbone.View.extend({

    tagName:  'tr',

    template: _.template($('#task-template').html()),

    events: {
      'click .rerun'    : 'rerun',
      'click .view'     : 'view',
      'click .destroy'  : 'destroy'
    },

    initialize: function() {
      this.model.bind('change', this.render, this);
      this.model.bind('destroy', this.remove, this);
      this.model.bind('error', this.invalid, this);
      return this;
    },

    render: function() {
      this.$el.html(this.template(this.model.toFullJSON()));
      this.$el.find('.status').html(this.model.get('status'));
      this.$(".timeago small").timeago();
      return this;
    },

    rerun: function() {
      window.location.hash = "#run";
      HellApp.form.trigger('task-form:add', this.model.toRerunJSON());
    },

    view: function() {
      window.location.hash = "#run";
      this.model.view();
    },

    destroy: function() {
      this.model.destroy();
    }

  });

  var TaskList = Backbone.Collection.extend({

    model: Task,

    localStorage: new Store('hell-tasks'),

    initialize: function() {
      this.bind('add', this.onTaskAdded, this);
    },

    onTaskAdded: function(task, collection, options) {
      task.save();
      task.execute();
    },

    comparator: function(task) {
      return task.get('timestamp');
    },

    clear: function() {
      var ids = this.pluck("id"),
          that = this;

      // We need to iterate over the ids because indexes
      // change for models when iterating over the collection
      // using _.each()
      _.each(ids, function(id) { that.get(id).destroy(); });
    },

    addTask: function(data, options) {
      var task = new Task();
      task.on('errors', options.error);
      task.on('validates', this.add, this);
      task.set(data, {silent: true});
      task.validates();
      return task;
    }

  });

  window.Tasks = new TaskList();

  var TaskCollectionView = Backbone.View.extend({

    el: $('#history'),

    events: {
      'click .clear-tasks': 'clearTasks'
    },

    initialize: function() {
      Tasks.bind('add', this.addOne, this);
      Tasks.bind('reset', this.addAll, this);
      Tasks.bind('all', this.render, this);
      Tasks.fetch();
    },

    addOne: function(task) {
      var view = new TaskView({model: task});
      this.$('tbody').prepend(view.render().el);
    },

    addAll: function() {
      Tasks.each(this.addOne);
    },

    clearTasks: function(e) {
      Tasks.clear();
    }

  });

  var TaskFormView = Backbone.View.extend({

    el: $('#run'),

    events: {
      'submit form'     : 'onFormSubmit'
    },

    initialize: function() {
      _.bindAll(this, 'onError');
      this.bind('task-form:add', this.onTaskAdd, this);
      this.$('.cap-command').typeahead({source: HellApp.tasks});
      return this;
    },

    onError: function(task, errors) {
      _.each(errors, function(fieldErrors) {
        _.each(fieldErrors, function(error) {
          $.bootstrapGrowl(error, {allow_dismiss: false, type: 'error', width: 200});
        });
      });
    },

    onFormSubmit: function(e) {
      e.preventDefault();

      var data = {};
      $.each(this.$('form').serializeArray(), function(i, field) {
          data[field.name] = field.value;
      });

      if (this.$('.environment .active').length) {
        data.environment = this.$('.environment .active').attr('environment');
      }

      this.trigger('task-form:add', data);
    },

    onTaskAdd: function(data) {
      Tasks.addTask(data, { error: this.onError });
      return this;
    }

  });

  HellApp = HellApp || {};
  _.extend(HellApp, {
    toggle_overlay: function() {
      var docHeight = $(document).height();
      if ($('.black-overlay').is(":visible")) {
        $('.black-overlay').hide();
        $('.progress').hide();
      } else {
        $('.black-overlay').height(docHeight);
        $('.black-overlay').show();
        $('.progress').show();
      }
    },
    set_flash: function(message, flash_type) {
      flash_type = flash_type || "error";
      $.bootstrapGrowl(message, {
        allow_dismiss: false, type: flash_type, width: 200
      });
    },
    close_sockets: function(src) {
      if (src !== null) {
        src.close();
        src = null;
      }
      if (src === undefined) {
        src = null;
      }
    },
    collection: new TaskCollectionView(),
    form: new TaskFormView()
  });

  // HACK: This should be moved into a Backbone View or Router

  // Function to activate the tab
  function activateTab() {
    var activeTab = $('[href=' + window.location.hash.replace('/', '') + ']');
    if (activeTab) activeTab.tab('show');
  }

  // Trigger when the page loads
  activateTab();

  // Trigger when the hash changes (forward / back)
  $(window).hashchange(function(e) {
    activateTab();
  });

  // Change hash when a tab changes
  $('a[data-toggle="tab"], a[data-toggle="pill"]').on('shown', function () {
      window.location.hash = '/' + $(this).attr('href').replace('#', '');
  });

});
