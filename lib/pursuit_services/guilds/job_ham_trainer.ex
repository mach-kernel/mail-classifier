defmodule PursuitServices.Guilds.JobHamTrainer do
  def start do
    {:ok, job_source} = 
      PursuitServices.Sources.Gmail.start(email: "me@davidstancu.me")

    {:ok, ham_source} =
      PursuitServices.Sources.SpamAssassin.start(
        archive_name: "20030228_easy_ham.tar.bz2"
      )

    {:ok, classifier} = PursuitServices.Classifier.Bayes.start("JobHam")

    {:ok, combiner} = 
      PursuitServices.Classifier.MulticlassCombiner.start(
        %{job: job_source, ham: ham_source},
        classifier,
        2
      )


    GenServer.call(job_source, {:bind_combiner_supervisor, combiner})
    GenServer.call(ham_source, {:bind_combiner_supervisor, combiner})
    GenServer.call(job_source, :publish_on)
    GenServer.call(ham_source, :publish_on)

    GenServer.cast(combiner, :send_train_data)
  end
end