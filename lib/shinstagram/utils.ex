defmodule Shinstagram.Utils do
  require Logger

  @image_model "stability-ai/sdxl"

  def parse_chat({:ok, %{choices: [%{"message" => %{"content" => content}} | _]}}) do
    {:ok, content}
  end

  def save_r2(uuid, image_url) do
    image_binary = Req.get!(image_url).body

    file_name = "ShinstagramImages/prediction-#{uuid}.png"
    bucket = System.get_env("AWS_BUCKET_NAME")

    %{status_code: 200} =
      ExAws.S3.put_object(bucket, file_name, image_binary)
      |> ExAws.request!()

    {:ok, "#{System.get_env("S3_PUBLIC_URL")}/#{file_name}"}
  end

  def gen_image({:ok, image_prompt}), do: gen_image(image_prompt)

  @doc """
  Generates an image given a prompt. Returns {:ok, url} or {:error, error}.
  """
  def gen_image(image_prompt) when is_binary(image_prompt) do
    Logger.info("Generating image for #{image_prompt}")
    model = Replicate.Models.get!(@image_model)
    version = Replicate.Models.get_latest_version!(model)

    {:ok, prediction} = Replicate.Predictions.create(version, %{prompt: image_prompt})
    {:ok, prediction} = Replicate.Predictions.wait(prediction)

    Logger.info("Image generated: #{prediction.output}")

    result = List.first(prediction.output)
    save_r2(prediction.id, result)
  end

  def chat_completion(text) do
    text
    |> OpenAI.chat_completion()
    |> Utils.parse_chat()
  end
end
