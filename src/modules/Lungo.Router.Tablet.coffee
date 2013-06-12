###
Handles the <sections> and <articles> to show on a tablet device

@namespace Lungo
@class Router

@author Ignacio Olalde <ina@tapquo.com> || @piniphone
###


Lungo.RouterTablet = do (lng = Lungo) ->

  C                   = lng.Constants
  HASHTAG             = "#"
  _history            = []
  _animating          = false
  _callbackSection    = undefined
  _fromCallback       = false

  ###
  Navigate to a <section>.
  @method   section
  @param    {string} Id of the <section>
  ###
  section = (section_id) ->
    return false if _animating
    current = lng.Element.Cache.section
    if _notCurrentTarget current, section_id
      query = C.ELEMENT.SECTION + HASHTAG + section_id
      future = if current then current.siblings(query) else lng.dom(query)
      if future.length
        _show future, current
        step section_id
        do _url unless Lungo.Config.history is false
        do _updateNavigationElements
    # else do lng.Aside.hide
    # console.error "Forward -->", _history

  ###
  Return to previous section.
  @method   back
  ###
  back = (animating = true) ->
    return false if _animating
    do _removeLast
    current = lng.Element.Cache.section
    query = C.ELEMENT.SECTION + HASHTAG + history()
    future = current.siblings(query)
    if future.length
      _show future, current, true, animating
      do _url unless Lungo.Config.history is false
      do _updateNavigationElements
    # console.error "Backward -->", _history

  ###
  Displays the <article> in a particular <section>.
  @method   article
  @param    {string} <section> Id
  @param    {string} <article> Id
  ###
  article = (section_id, article_id, element) ->
    if not _sameSection() then back false
    target = lng.dom "article##{article_id}"
    if target.length > 0
      section = target.closest C.ELEMENT.SECTION
      lng.Router.section(section.attr("id"))
      section.children("#{C.ELEMENT.ARTICLE}.#{C.CLASS.ACTIVE}").removeClass(C.CLASS.ACTIVE).trigger C.TRIGGER.UNLOAD
      target.addClass(C.CLASS.ACTIVE).trigger(C.TRIGGER.LOAD)
      # lng.Element.Cache.article.removeClass(C.CLASS.ACTIVE).trigger C.TRIGGER.UNLOAD
      # lng.Element.Cache.article = target.addClass(C.CLASS.ACTIVE).trigger(C.TRIGGER.LOAD)

      if element?.data(C.ATTRIBUTE.TITLE)?
        # lng.Element.Cache.section.find(C.QUERY.TITLE).text element.data(C.ATTRIBUTE.TITLE)
        section.find(C.QUERY.TITLE).text element.data(C.ATTRIBUTE.TITLE)
      do _url unless Lungo.Config.history is false
      _updateNavigationElements article_id

  ###
  Triggered when <section> animation ends. Reset animation classes of section and aside
  @method   animationEnd
  @param    {eventObject}
  ###
  animationEnd = (event) ->
    section = lng.dom(event.target)
    direction = section.data(C.ATTRIBUTE.DIRECTION)
    if direction
      section.removeClass C.CLASS.SHOW if direction is "out" or direction is "back-out"
      section.removeAttr "data-#{C.ATTRIBUTE.DIRECTION}"
      if _callbackSection?
        _fromCallback = true
        _show _callbackSection, undefined
        _callbackSection = undefined

    if section.hasClass("asideHidding") then section.removeClass("asideHidding").removeClass("aside")
    if section.hasClass("asideShowing") then section.removeClass("asideShowing").addClass("aside")
    if section.hasClass("shadowing")    then section.removeClass("shadowing").addClass("shadow")
    if section.hasClass("unshadowing")  then section.removeClass("unshadowing").removeClass("shadow")
    _animating = false

  ###
  Create a new element to the browsing history based on the current section id.
  @method step
  @param  {string} Id of the section
  ###
  step = (section_id) -> _history.push section_id if section_id isnt history()

  ###
  Returns the current browsing history section id.
  @method history
  @return {string} Current section id
  ###
  history = -> _history[_history.length - 1]

  ###
  Private methods
  ###
  _show = (future, current, backward=false) ->
    unless current? then _showFuture(future)
    else
      if backward then _showBackward(current, future)
      else _showForward(current, future)
      lng.Section.show(current, future)
    _fromCallback = false

  _showFuture = (future, animating=false) ->
    current = undefined
    lng.Section.show(current, future)
    if not animating and not _fromCallback then future.addClass(C.CLASS.SHOW)
    else _applyDirection(future, "in")
    _checkAside(current, future)

  _showForward = (current, future) ->
    asideHandled = false
    if _isChild(current, future) then _applyDirection(future, "in")
    else
      do _removeLast
      parent_id = _parentId(future)
      hideSelector = "section.#{C.CLASS.SHOW}"
      if parent_id then hideSelector += ":not(##{parent_id})"
      elements = lng.dom(hideSelector)
      if lng.Element.Cache.aside
        do lng.Aside.hide
        elements.removeClass C.CLASS.SHOW
        _showFuture future, true
        asideHandled = true
      else
        _applyDirection(elements, "back-out")
        _callbackSection = future

    if not asideHandled and not _fromCallback
      _checkAside(current, future)

  _showBackward = (current, future) ->
    _applyDirection(current, "back-out")
    showSections = lng.dom("section.#{C.CLASS.SHOW}:not(##{current.attr('id')})")
    if showSections.length is 1 and showSections.first().data("children")?
      lng.Aside.hide (-> lng.Aside.show showSections.first().data("aside"))
    _callbackSection = future

  _visibleParent = (section) ->
    return lng.dom("section[data-children~=#{section.attr('id')}].#{C.CLASS.SHOW}")

  _checkAside = (current, target) ->
    aside_id = target.data("aside")
    unless aside_id then do lng.Aside.hide
    else if current?
      do lng.Aside.hide unless lng.Element.Cache.aside?.hasClass("box")
    else if target.data("children") and lng.dom("section.#{C.CLASS.SHOW}").length is 1
      lng.Aside.show(aside_id)
    else if not target.data("children")
      unless _parentId target
        lng.Aside.showFix(aside_id)

  _targetIsChildren = (current, target) ->
    children = current?.data("children")
    return false unless children
    target_id = target.attr "id"
    return children.indexOf(target_id) isnt -1

  _parentId = (section) ->
    parent = lng.dom("[data-children~=#{section.attr('id')}]")
    if parent.length then return parent.attr("id")
    return null

  _isChild = (current, future) ->
    children = current.data("children")
    return false unless children
    target_id = future.attr "id"
    return children.indexOf(target_id) isnt -1

  _applyDirection = (section, direction) ->
    isForward = direction.indexOf("in") >= 0
    apply = false
    if isForward
      unless section.hasClass(C.CLASS.SHOW) then apply = true
    else apply = true
    if apply
      section.addClass(C.CLASS.SHOW)
      section.data(C.ATTRIBUTE.DIRECTION, direction) if section.data(C.TRANSITION.ATTR)

  _sameSection = ->
    if not event or not lng.Element.Cache.section then return true
    dispacher_section = lng.dom(event.target).closest("section,aside")
    same = dispacher_section.attr("id") is lng.Element.Cache.section.attr("id")
    return same

  _notCurrentTarget = (current, id) -> current?.attr(C.ATTRIBUTE.ID) isnt id

  _url = ->
    _hashed_url = ""
    _hashed_url += "#{section}/" for section in _history
    _hashed_url += lng.Element.Cache.article.attr "id"
    setTimeout (-> window.location.hash = _hashed_url), 0

  _updateNavigationElements = (article_id) ->
    article_id = lng.Element.Cache.article.attr(C.ATTRIBUTE.ID) unless article_id
    # Active visual signal for elements
    links = lng.dom(C.QUERY.ARTICLE_ROUTER).removeClass(C.CLASS.ACTIVE)
    links.filter("[data-view-article=#{article_id}]").addClass(C.CLASS.ACTIVE)
    # Hide/Show elements in current article
    nav = lng.Element.Cache.section.find(C.QUERY.ARTICLE_REFERENCE).addClass C.CLASS.HIDE
    nav.filter("[data-article~='#{article_id}']").removeClass C.CLASS.HIDE

  _removeLast = ->
    if _history.length > 1
      _history.length -= 1


  section : section
  back    : back
  article : article
  history : history
  step    : step
  animationEnd : animationEnd


