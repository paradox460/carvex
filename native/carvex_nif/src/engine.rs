//! Running carve-rs off the BEAM scheduler stack, and mapping its errors.

use std::any::Any;
use std::thread;

/// Virtual stack reservation for the engine thread; pages commit lazily.
const STACK: usize = 64 * 1024 * 1024;

/// Error category, encoded as an atom (`:profile_violation`, `:invalid_ast`, ...).
#[derive(NifUnitEnum, Clone, Copy, Debug)]
pub enum ErrorKind {
    ProfileViolation,
    InvalidAst,
    Render,
    InvalidOption,
    Panic,
}

/// Encodes as `{:error, {kind, message}}` when returned in a `Result`.
pub type NifError = (ErrorKind, String);

pub fn error(kind: ErrorKind, e: impl std::fmt::Display) -> NifError {
    (kind, e.to_string())
}

pub fn profile(e: carve::ProfileViolationError) -> NifError {
    error(ErrorKind::ProfileViolation, e)
}

pub fn ast(e: carve::AstJsonError) -> NifError {
    error(ErrorKind::InvalidAst, e)
}

pub fn render(e: impl std::fmt::Display) -> NifError {
    error(ErrorKind::Render, e)
}

/// A profile refusal keeps its kind when it arrives through the Carve writer.
pub fn write(e: carve::CarveWriteError) -> NifError {
    match e {
        carve::CarveWriteError::Profile(e) => profile(e),
        carve::CarveWriteError::Render(e) => render(e),
    }
}

pub fn invalid_option(message: impl Into<String>) -> NifError {
    (ErrorKind::InvalidOption, message.into())
}

/// Runs carve-rs on a scoped thread with a large stack (BEAM dirty schedulers
/// have ~320 KB stacks; the engine recurses to its 200-container cap) and turns
/// a panic into `{:panic, message}` instead of unwinding into the VM.
pub fn isolated<T: Send>(f: impl FnOnce() -> Result<T, NifError> + Send) -> Result<T, NifError> {
    thread::scope(|scope| {
        let handle = thread::Builder::new()
            .name("carvex-engine".into())
            .stack_size(STACK)
            .spawn_scoped(scope, f)
            .map_err(|e| error(ErrorKind::Panic, e))?;
        handle
            .join()
            .unwrap_or_else(|payload| Err((ErrorKind::Panic, panic_message(payload))))
    })
}

fn panic_message(payload: Box<dyn Any + Send>) -> String {
    match payload.downcast::<String>() {
        Ok(s) => *s,
        Err(payload) => match payload.downcast::<&str>() {
            Ok(s) => (*s).to_string(),
            Err(_) => "carve engine panicked".to_string(),
        },
    }
}
