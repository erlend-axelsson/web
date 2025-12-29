defmodule Web.Style.Palette do
  def rosewater, do: " #F2D5CF"
  def flamingo, do: " #EEBEBE"
  def pink, do: " #F4B8E4"
  def mauve, do: " #CA9EE6"
  def red, do: " #E78284"
  def maroon, do: " #EA999C"
  def peach, do: " #EF9F76"
  def yellow, do: " #E5C890"
  def green, do: " #A6D189"
  def teal, do: " #81C8BE"
  def sky, do: " #99D1DB"
  def sapphire, do: " #85C1DC"
  def blue, do: " #8CAAEE"
  def lavender, do: " #BABBF1"
  def text, do: " #C6D0F5"
  def subtext_1, do: " #B5BFE2"
  def subtext_0, do: " #A5ADCE"
  def overlay_2, do: " #949CBB"
  def overlay_1, do: " #838BA7"
  def overlay_0, do: " #737994"
  def surface_2, do: " #626880"
  def surface_1, do: " #51576D"
  def surface_0, do: " #414559"
  def base, do: " #303446"
  def mantle, do: " #292C3C"
  def crust, do: " #232634"
  def bold(), do: "bold"
  def bold(s), do: "bold " <> s
  def nobold(), do: "nobold"
  def nobold(s), do: "nobold " <> s
  def italic(), do: "italic"
  def italic(s), do: "italic " <> s
  def noitalic(), do: "noitalic"
  def noitalic(s), do: "noitalic " <> s
  def border(s), do: "border:" <> s
end
