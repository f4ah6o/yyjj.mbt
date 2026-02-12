///|
/// Keep quickcheck dependency marked as used by the root package.
fn _keep_quickcheck_reference() -> Unit {
  let _ = @qc.pure(())
}
