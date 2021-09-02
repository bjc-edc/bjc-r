-- .todo, .comment, .commentBig
function Block (element)
  if element.classes and (
      element.classes[1] == 'todo' or element.classes[1] == 'comment'
      or element.classes[1] == 'commentBig'
    ) then
    print 'Removing Developer Comment'
    -- print("FOUND ELEMENT " .. element.attr)
    return {}
  end
  return element
end

-- Replace absolute /bjc-r with a relative URL for easy conversion.
function Image(element)
  element.src = string.gsub(element.src, "/bjc%-r", ".")
  return element
end

-- Set the document date
-- TODO: In the word template this needs to be a footnote.
function Meta(m)
  m.date = os.date("%B %e, %Y")
  return m
end
