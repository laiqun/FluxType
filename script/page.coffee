class Page
  constructor: (@base, @config)->
    @_initTemplate()

    @rows = []

    default_config = {
      font_size: 18
      padding: 4
      spacing: 3
    }
    @config = $.extend default_config, @config

    @config.space_size  = @config.font_size + (@config.padding * 2) + (@config.spacing * 2)
    @config.num_columns = Math.floor (@$container.innerWidth()/@config.space_size)+1
    @config.num_rows    = Math.floor @config.height/@config.space_size
    @config.max_chars   = @config.num_columns * @config.num_rows

    @_initText()

  nextSpace: =>
    @current_space.deselect()

    space = @current_space
    next = space.row.spaces[space.index+1]
    if next_row = @rows[space.row.index+1]
      next = _.first(next_row.spaces) unless next
    return @drawText() unless next

    @current_space = next
    @nextSpace() unless @current_space.typeable

    @current_space.select()

  resetRows: =>
    _.each @rows, (row)=> row.destroy()
    @rows = _.map [0..@config.num_rows], (index)=> new Page.Row this, index

  drawText: =>
    @resetRows()
    @word_index = 0 if @word_index >= @words.length
    _.each @rows, (row, row_index)=>
      for word, word_index in (_.rest @words, @word_index)
        if _.rest(row.spaces, row.space_index).length >= word.chars.length
          row.push word.chars...
          @word_index += 1
        else
          last_space = row.spaces[row.space_index-1]
          last_space.isLast() if last_space
          _.each _.rest(row.spaces, row.space_index), (space)=> space.setEmpty()
          break

    @current_space = _.first(_.first(@rows).spaces)
    @nextSpace() unless @current_space.typeable
    @current_space.select()

  _initText: (text)=>
    unless text
      return @base.defaultText (text)=>
        @_initText text

    @words = _.map text.split(/[\s\n\t]+/), (word)=> new Page.Word this, word
    @word_index = 0

    @drawText()

  _initTemplate: =>
    element_id_index = {
      outer_container: 'page-outer-container'
      container: 'page-container'
    }

    html = """
    <div id='#{element_id_index.outer_container}'>
      <div id='#{element_id_index.container}'>
      </div>
      <div class='clear'></div>
    </div>
    """

    ($ html).appendTo @base.$container

    @$container = ($ "##{element_id_index.container}")

  class @Row
    constructor: (@page, @index)->
      @spaces = _.map [0..@page.config.num_columns], (index)=> new Page.Row.Space @page, this, index
      (_.first @spaces).isFirst()

      @space_index = 0

    push: (chars...)=>
      _.each chars, (char, char_index)=>
        @spaces[@space_index].set char
        @space_index += 1
      @space_index += 1

    destroy: =>
      _.each @spaces, (space)=> space.$element.remove()

    class @Space
      constructor: (@page, @row, @index)->
        @$element = ($ "<div class='page-row-space space'>&nbsp;</div>").appendTo @page.$container

        @$element.css
          width: @page.config.font_size

        @typeable = true

        @char_codes = [" ".charCodeAt(0)]

      setEmpty: =>
        @typeable = false
        @$element.removeClass 'space'
        @$element.addClass 'empty'

      set: (@char)=>
        @$element.text @char.text
        @$element.addClass 'page-row-char'
        @$element.removeClass 'space'

        @typeable = @char.typeable

        unless @typeable
          @$element.addClass 'skip'

        # if row ends in a non-space, prepend a space to the next
        if @index == @row.spaces.length-1 && @page.rows[@row.index+1]
          @page.rows[@row.index+1].space_index += 1

      match: (charCode)=>
        if @miss_space
          if charCode == KEYS.BACKSPACE
            @miss_space.$element.remove()
            @miss_space = undefined
          return false

        if @char
          @char.code == charCode
        else
          _.include @char_codes, charCode

      select: =>
        @$element.addClass 'active'

      deselect: =>
        @$element.removeClass 'active'

      hit: =>
        @$element.addClass 'hit'

      miss: (charCode)=>
        @$element.addClass 'miss'

        @miss_space ||= new Page.Row.Space.MissSpace this
        @miss_space.set String.fromCharCode(charCode)

      isFirst: =>
        @$element.addClass 'first'

      isLast: =>
        @char_codes.push "\r".charCodeAt(0)

      class @MissSpace
        constructor: (@space)->
          @$element = ($ "<div class='page-row-miss-space'>&nbsp;</div>").appendTo @space.page.$container
          @$element.css
            position: 'absolute'
            top: @space.$element.position().top+1
            left: @space.$element.position().left+1
            width: @space.$element.width()
            height: @space.$element.height()

        set: (text)=>
          @$element.text text

  class @Word
    constructor: (@page, @text)->
      @chars = _.map @text.split(''), (char)=> new Page.Word.Char @page, this, char

    class @Char
      @TYPEABLE_MATCHER = /^[-a-z0-9_~`!@#$%^&*\(\)-+=\|\\\}\{\[\]"':;?\/><,.\s\t]$/i
      constructor: (@page, @word, @text)->
        @typeable = @text.match(Page.Word.Char.TYPEABLE_MATCHER) != null
        @code = @text.charCodeAt(0)