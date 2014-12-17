DomUtils =
  #
  # Runs :callback if the DOM has loaded, otherwise runs it on load
  #
  documentReady: do ->
    loaded = false
    window.addEventListener("DOMContentLoaded", -> loaded = true)
    (callback) -> if loaded then callback() else window.addEventListener("DOMContentLoaded", callback)

  #
  # Adds a list of elements to a page.
  # Note that adding these nodes all at once (via the parent div) is significantly faster than one-by-one.
  #
  addElementList: (els, overlayOptions) ->
    parent = document.createElement("div")
    parent.id = overlayOptions.id if overlayOptions.id?
    parent.className = overlayOptions.className if overlayOptions.className?
    parent.appendChild(el) for el in els

    document.documentElement.appendChild(parent)
    parent

  #
  # Remove an element from its DOM tree.
  #
  removeElement: (el) -> el.parentNode.removeChild el

  #
  # Takes an array of XPath selectors, adds the necessary namespaces (currently only XHTML), and applies them
  # to the document root. The namespaceResolver in evaluateXPath should be kept in sync with the namespaces
  # here.
  #
  makeXPath: (elementArray) ->
    xpath = []
    for element in elementArray
      xpath.push("//" + element, "//xhtml:" + element)
    xpath.join(" | ")

  evaluateXPath: (xpath, resultType) ->
    namespaceResolver = (namespace) ->
      if (namespace == "xhtml") then "http://www.w3.org/1999/xhtml" else null
    document.evaluate(xpath, document.documentElement, namespaceResolver, resultType, null)

  #
  # Returns the first visible clientRect of an element if it exists. Otherwise it returns null.
  #
  getVisibleClientRect: (element) ->
    # Note: this call will be expensive if we modify the DOM in between calls.
    clientRects = ({
      top: clientRect.top, right: clientRect.right, bottom: clientRect.bottom, left: clientRect.left,
      width: clientRect.width, height: clientRect.height
    } for clientRect in element.getClientRects())

    for clientRect in clientRects
      # If the link has zero dimensions, it may be wrapping visible
      # but floated elements. Check for this.
      if (clientRect.width == 0 || clientRect.height == 0)
        for child in element.children
          computedStyle = window.getComputedStyle(child, null)
          # Ignore child elements which are not floated and not absolutely positioned for parent elements with
          # zero width/height
          continue if (computedStyle.getPropertyValue('float') == 'none' &&
            computedStyle.getPropertyValue('position') != 'absolute')
          childClientRect = @getVisibleClientRect(child)
          continue if (childClientRect == null)
          return childClientRect

      else
        clientRect = @cropRectToVisible clientRect

        if (!clientRect || clientRect.width < 3 || clientRect.height < 3)
          continue

        # eliminate invisible elements (see test_harnesses/visibility_test.html)
        computedStyle = window.getComputedStyle(element, null)
        if (computedStyle.getPropertyValue('visibility') != 'visible' ||
            computedStyle.getPropertyValue('display') == 'none')
          continue

        return clientRect

    null

  cropRectToVisible: (rect) ->
    if (rect.top < 0)
      rect.height += rect.top
      rect.top = 0

    if (rect.left < 0)
      rect.width += rect.left
      rect.left = 0

    if (rect.top >= window.innerHeight - 4 || rect.left  >= window.innerWidth - 4)
      null
    else
      rect


  getClientRectsForAreas: (imgClientRect, areas) ->
    rects = []
    for area in areas
      coords = area.coords.split(",").map((coord) -> parseInt(coord, 10))
      shape = area.shape.toLowerCase()
      if shape == "rect" or coords.length == 4
        [x1, y1, x2, y2] = coords
      else if shape == "circle" or coords.length == 3
        [x, y, r] = coords
        x1 = x - r
        x2 = x + r
        y1 = y - r
        y2 = y + r
      else
        # Just consider the rectangle surrounding the first two points in a polygon. It's possible to do
        # something more sophisticated, but likely not worth the effort.
        [x1, y1, x2, y2] = coords

      rect = @cropRectToVisible
        top: imgClientRect.top + y1
        left: imgClientRect.left + x1
        right: imgClientRect.left + x2
        bottom: imgClientRect.top + y2
        width: x2 - x1
        height: y2 - y1

      rects.push {element: area, rect: rect} unless not rect or isNaN rect.top
    rects

  #
  # Selectable means that we should use the simulateSelect method to activate the element instead of a click.
  #
  # The html5 input types that should use simulateSelect are:
  #   ["date", "datetime", "datetime-local", "email", "month", "number", "password", "range", "search",
  #    "tel", "text", "time", "url", "week"]
  # An unknown type will be treated the same as "text", in the same way that the browser does.
  #
  isSelectable: (element) ->
    unselectableTypes = ["button", "checkbox", "color", "file", "hidden", "image", "radio", "reset", "submit"]
    (element.nodeName.toLowerCase() == "input" && unselectableTypes.indexOf(element.type) == -1) ||
        element.nodeName.toLowerCase() == "textarea"

  simulateSelect: (element) ->
    element.focus()
    # When focusing a textbox, put the selection caret at the end of the textbox's contents.
    # For some HTML5 input types (eg. date) we can't position the caret, so we wrap this with a try.
    try element.setSelectionRange(element.value.length, element.value.length)

  simulateClick: (element, modifiers) ->
    modifiers ||= {}

    eventSequence = ["mouseover", "mousedown", "mouseup", "click"]
    for event in eventSequence
      mouseEvent = document.createEvent("MouseEvents")
      mouseEvent.initMouseEvent(event, true, true, window, 1, 0, 0, 0, 0, modifiers.ctrlKey, modifiers.altKey,
      modifiers.shiftKey, modifiers.metaKey, 0, null)
      # Debugging note: Firefox will not execute the element's default action if we dispatch this click event,
      # but Webkit will. Dispatching a click on an input box does not seem to focus it; we do that separately
      element.dispatchEvent(mouseEvent)

  # momentarily flash a rectangular border to give user some visual feedback
  flashRect: (rect) ->
    flashEl = document.createElement("div")
    flashEl.id = "vimiumFlash"
    flashEl.className = "vimiumReset"
    flashEl.style.left = rect.left + window.scrollX + "px"
    flashEl.style.top = rect.top  + window.scrollY  + "px"
    flashEl.style.width = rect.width + "px"
    flashEl.style.height = rect.height + "px"
    document.documentElement.appendChild(flashEl)
    setTimeout((-> DomUtils.removeElement flashEl), 400)

  suppressPropagation: (event) ->
    event.stopImmediatePropagation()

  suppressEvent: (event) ->
    event.preventDefault()
    @suppressPropagation(event)

root = exports ? window
root.DomUtils = DomUtils
