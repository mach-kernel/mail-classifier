defmodule PursuitServices.Guilds.JobHamTrainer do
  alias PursuitServices.Sources
  alias PursuitServices.Classifier

  require Logger

  def start_link do
    alias PursuitServices.Sources
    alias PursuitServices.Classifier
    :observer.start

    {:ok, job_source} = 
      PursuitServices.Sources.Gmail.start(email: "me@davidstancu.me")

    {:ok, ham_source} = Sources.SpamAssassin.start(
      archive_name: "20030228_easy_ham.tar.bz2"
    )

    {:ok, classifier} = Classifier.Bayes.start("JobHam")

    {:ok, combiner} = Classifier.MulticlassCombiner.start(
      %{ job_source => :job, ham_source => :ham }, classifier, 2
    )


    GenServer.call(job_source, {:bind_combiner_supervisor, combiner})
    GenServer.call(ham_source, {:bind_combiner_supervisor, combiner})
    GenServer.call(job_source, :publish_on)
    GenServer.call(ham_source, :publish_on)

    :timer.sleep(60000 * 10)

    GenServer.call(classifier, :persist)

    {:ok, combiner}
  end
end