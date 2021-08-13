job "ping" {
  datacenters = ["dc1"]

  type = "service"

  group "example" {
    count = 2

    task "ping" {
      driver = "raw_exec"

      config {
        command = "/bin/ping"
        args    = ["-c", "1000", "google.com"]
      }
    }
  }
}
