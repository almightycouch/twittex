defmodule TwittexClassifierTest do
  use ExUnit.Case

  import Twittex.Classifier

  test "training corpora" do
    bayes = train_corpora()
    assert :positive == classify_one(bayes, "blue")
    assert :negative == classify_one(bayes, "ikea")
  end
end
