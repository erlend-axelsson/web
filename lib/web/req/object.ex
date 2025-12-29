defmodule Web.Req.Object do
  require Web.Helper

  def get(key) do
    Req.get(Web.Req.Base.base_req(), url: Web.Helper.slash_prefix_m(key))
  end
end
