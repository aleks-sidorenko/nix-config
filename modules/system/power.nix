{
  # Idle sleep only: closing the lid sleeps the machine regardless, and display
  # sleep stays untouched since processes keep running with the screen off.
  den.aspects.system.power.darwin.power.sleep.computer = "never";
}
