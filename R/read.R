#' @title Read and return a drake target/import from the cache.
#' @description Does not delete the item from the cache.
#' @seealso [loadd()], [cached()],
#'   [built()], \code{link{imported}}, [drake_plan()],
#'   [make()]
#' @export
#' @return The cached value of the `target`.
#' @inheritParams cached
#' @param target If `character_only` is `TRUE`, then
#'   `target` is a character string naming the object to read.
#'   Otherwise, `target` is an unquoted symbol with the name of the
#'   object.
#' @param character_only logical, whether `name` should be treated
#'   as a character or a symbol
#'   (just like `character.only` in [library()]).
#' @param namespace optional character string,
#'   name of the `storr` namespace to read from.
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_basic_example() # Get the code with drake_example("basic").
#' make(my_plan) # Run the project, build the targets.
#' readd(reg1) # Return imported object 'reg1' from the cache.
#' readd(small) # Return targets 'small' from the cache.
#' readd("large", character_only = TRUE) # Return 'large' from the cache.
#' # For external files, only the fingerprint/hash is stored.
#' readd(file_store("report.md"), character_only = TRUE)
#' })
#' }
readd <- function(
  target,
  character_only = FALSE,
  path = getwd(),
  search = TRUE,
  cache = drake::get_cache(path = path, search = search, verbose = verbose),
  namespace = NULL,
  verbose = drake::default_verbose()
){
  # if the cache is null after trying get_cache:
  if (is.null(cache)){
    stop("cannot find drake cache.")
  }
  if (!character_only){
    target <- as.character(substitute(target))
  }
  if (is.null(namespace)){
    namespace <- cache$default_namespace
  }
  cache$get(
    standardize_filename(target),
    namespace = namespace,
    use_cache = TRUE
  )
}

#' @title Load one or more targets or imports from the drake cache.
#' @description Loads the object(s) into the
#' current workspace (or environment `envir` if given). Defaults
#' to loading the entire cache if you do not supply anything
#' to arguments `...` or `list`.
#' @details `loadd()` excludes foreign imports:
#'   R objects not originally defined in `envir`
#'   when [make()] last imported them.
#'   To get these objects, use [readd()].
#' @seealso [readd()], [cached()], [built()],
#'   [imported()], [drake_plan()], [make()],
#' @export
#' @return `NULL`
#'
#' @inheritParams cached
#'
#' @param ... targets to load from the cache: as names (symbols),
#'   character strings, or `dplyr`-style `tidyselect`
#'   commands such as `starts_with()`.
#'
#' @param list character vector naming targets to be loaded from the
#'   cache. Similar to the `list` argument of [remove()].
#'
#' @param imported_only logical, whether only imported objects
#'   should be loaded.
#'
#' @param namespace character scalar,
#'   name of an optional storr namespace to load from.
#'
#' @param envir environment to load objects into. Defaults to the
#'   calling environment (current workspace).
#'
#' @param jobs number of parallel jobs for loading objects. On
#'   non-Windows systems, the loading process for multiple objects
#'   can be lightly parallelized via `parallel::mclapply()`.
#'   just set jobs to be an integer greater than 1. On Windows,
#'   `jobs` is automatically demoted to 1.
#'
#' @param deps logical, whether to load any cached
#'   dependencies of the targets
#'   instead of the targets themselves.
#'   This is useful if you know your
#'   target failed and you want to debug the command in an interactive
#'   session with the dependencies in your workspace.
#'   One caveat: to find the dependencies,
#'   [loadd()] uses information that was stored
#'   in a [drake_config()] list and cached
#'   during the last [make()].
#'   That means you need to have already called [make()]
#'   if you set `deps` to `TRUE`.
#'
#' @param lazy either a string or a logical. Choices:
#'   - `"eager"`: no lazy loading. The target is loaded right away
#'     with [assign()].
#'   - `"promise"`: lazy loading with [delayedAssign()]
#'   - `"bind"`: lazy loading with active bindings:
#'     [bindr::populate_env()].
#'   - `TRUE`: same as `"promise"`.
#'   - `FALSE`: same as `"eager"`.
#'
#' @param graph optional igraph object, representation
#'   of the workflow network for getting dependencies
#'   if `deps` is `TRUE`. If none is supplied,
#'   it will be read from the cache.
#'
#' @param replace logical. If `FALSE`,
#'   items already in your environment
#'   will not be replaced.
#'
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_basic_example() # Get the code with drake_example("basic").
#' make(my_plan) # Run the projects, build the targets.
#' loadd(small) # Load target 'small' into your workspace.
#' small
#' # For many targets, you can parallelize loadd()
#' # using the 'jobs' argument.
#' loadd(list = c("small", "large"), jobs = 2)
#' ls()
#' # How about tidyselect?
#' loadd(starts_with("summ"))
#' ls()
#' # Load the dependencies of the target, coef_regression2_small
#' loadd(coef_regression2_small, deps = TRUE)
#' ls()
#' # Load all the imported objects/functions.
#' # Note: loadd() excludes foreign imports
#' # (R objects not originally defined in `envir`
#' # when `make()` last imported them).
#' loadd(imported_only = TRUE)
#' ls()
#' # Load all the targets listed in the workflow plan
#' # of the previous `make()`.
#' # Be sure your computer has enough memory.
#' loadd()
#' ls()
#' # With files, you just get the fingerprint.
#' loadd(list = file_store("report.md"))
#' ls() # Should include "\"report.md\"".
#' get(file_store("report.md"))
#' })
#' }
loadd <- function(
  ...,
  list = character(0),
  imported_only = FALSE,
  path = getwd(),
  search = TRUE,
  cache = drake::get_cache(path = path, search = search, verbose = verbose),
  namespace = NULL,
  envir = parent.frame(),
  jobs = 1,
  verbose = drake::default_verbose(),
  deps = FALSE,
  lazy = "eager",
  graph = NULL,
  replace = TRUE
){
  force(envir)
  if (is.null(cache)){
    stop("cannot find drake cache.")
  }
  if (is.null(namespace)){
    namespace <- cache$default_namespace
  }
  targets <- drake_select(
    cache = cache, ..., namespaces = namespace, list = list)
  if (!length(targets)){
    targets <- cache$list()
  }
  if (imported_only){
    targets <- imported_only(targets = targets, cache = cache, jobs = jobs)
  }
  if (!length(targets)){
    stop("no targets to load.")
  }
  if (deps){
    if (is.null(graph)){
      graph <- read_drake_graph(cache = cache)
    }
    targets <- dependencies(targets = targets, config = list(graph = graph))
    exists <- lightly_parallelize(
      X = targets,
      FUN = cache$exists,
      jobs = jobs
    ) %>%
      unlist
    targets <- targets[exists]
  }
  if (!replace){
    targets <- setdiff(targets, ls(envir, all.names = TRUE))
  }
  targets <- exclude_foreign_imports(
    targets = targets,
    cache = cache,
    jobs = jobs
  )
  lightly_parallelize(
    X = targets, FUN = load_target, cache = cache,
    namespace = namespace, envir = envir,
    verbose = verbose, lazy = lazy
  )
  invisible()
}

exclude_foreign_imports <- function(targets, cache, jobs){
  parallel_filter(
    x = targets,
    f = is_not_foreign_import_obj,
    jobs = jobs,
    cache = cache
  )
}

is_not_foreign_import_obj <- function(target, cache){
  if (is_file(target)){
    return(TRUE)
  }
  if (!cache$exists(key = target, namespace = "meta")){
    return(FALSE)
  }
  meta <- diagnose(
    target = target,
    cache = cache,
    character_only = TRUE,
    verbose = FALSE
  )
  identical(meta$imported, FALSE) || identical(meta$foreign, FALSE)
}

parse_lazy_arg <- function(lazy){
  if (identical(lazy, FALSE)){
    "eager"
  } else if (identical(lazy, TRUE)){
    "promise"
  } else {
    match.arg(arg = lazy, choices = c("eager", "promise", "bind"))
  }
}

load_target <- function(target, cache, namespace, envir, verbose, lazy){
  lazy <- parse_lazy_arg(lazy)
  switch(
    lazy,
    eager = eager_load_target(
      target = target,
      cache = cache,
      namespace = namespace,
      envir = envir,
      verbose = verbose
    ),
    promise = promise_load_target(
      target = target,
      cache = cache,
      namespace = namespace,
      envir = envir,
      verbose = verbose
    ),
    bind = bind_load_target(
      target = target,
      cache = cache,
      namespace = namespace,
      envir = envir,
      verbose = verbose
    )
  )
}

#' @title Load a target right away (internal function)
#' @description This function is only exported
#' to make active bindings work safely.
#' It is not actually a user-side function.
#' @keywords internal
#' @export
#' @inheritParams loadd
eager_load_target <- function(target, cache, namespace, envir, verbose){
  value <- readd(
    target,
    character_only = TRUE,
    cache = cache,
    namespace = namespace,
    verbose = verbose
  )
  assign(x = target, value = value, envir = envir)
  local <- environment()
  rm(value, envir = local)
  invisible()
}

promise_load_target <- function(target, cache, namespace, envir, verbose){
  eval_env <- environment()
  delayedAssign(
    x = target,
    value = readd(
      target,
      character_only = TRUE,
      cache = cache,
      namespace = namespace,
      verbose = verbose
    ),
    eval.env = eval_env,
    assign.env = envir
  )
}

bind_load_target <- function(target, cache, namespace, envir, verbose){
  # Allow active bindings to overwrite existing variables.
  if (target %in% ls(envir)){
    message(
      "Replacing already-loaded variable ", target,
      " with an active binding."
    )
    remove(list = target, envir = envir)
  }
  bindr::populate_env(
    env = envir,
    names = as.character(target),
    fun = function(key, cache, namespace){
      if (!length(namespace)){
        # Now impractical to cover because loadd() checks the namespace,
        # but good to have around anyway.
        namespace <- cache$default_namespace # nocov
      }
      cache$get(
        key = as.character(key),
        namespace = as.character(namespace),
        use_cache = TRUE
      )
    },
    cache = cache,
    namespace = namespace
  )
}

#' @title Read the cached [drake_config()]
#'   list from the last [make()].
#' @description See [drake_config()] for more information
#' about drake's internal runtime configuration parameter list.
#' @seealso [make()]
#' @export
#' @return The cached master internal configuration list
#'   of the last [make()].
#'
#' @inheritParams cached
#'
#' @param jobs number of jobs for light parallelism.
#'   Supports 1 job only on Windows.
#'
#' @param envir Optional environment to fill in if
#'   `config$envir` was not cached. Defaults to your workspace.
#'
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_basic_example() # Get the code with drake_example("basic").
#' make(my_plan) # Run the project, build the targets.
#' # Retrieve the master internal configuration list from the cache.
#' read_drake_config()
#' })
#' }
read_drake_config <- function(
  path = getwd(),
  search = TRUE,
  cache = NULL,
  verbose = drake::default_verbose(),
  jobs = 1,
  envir = parent.frame()
){
  force(envir)
  if (is.null(cache)) {
    cache <- get_cache(path = path, search = search, verbose = verbose)
  }
  if (is.null(cache)) {
    stop("cannot find drake cache.")
  }
  keys <- cache$list(namespace = "config")
  out <- lightly_parallelize(
    X = keys,
    FUN = function(item){
      cache$get(key = item, namespace = "config", use_cache = FALSE)
    },
    jobs = jobs
  )
  names(out) <- keys
  if (is.null(out$envir)){
    out$envir <- envir
  }
  # The file system of the original config$cache could have moved.
  out$cache <- cache
  cache_path <- force_cache_path(cache)
  out
}

#' @title Read the igraph dependency network
#'   from your last attempted call to [make()].
#' @description For more user-friendly graphing utilities,
#' see [vis_drake_graph()]
#' and related functions.
#' @seealso [vis_drake_graph()], [read_drake_config()]
#' @export
#' @return An `igraph` object representing the dependency
#'   network of the workflow.
#'
#' @inheritParams cached
#'
#' @param ... arguments to [visNetwork()] via
#'   [vis_drake_graph()]
#'
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_basic_example() # Get the code with drake_example("basic").
#' make(my_plan) # Run the project, build the targets.
#' # Retrieve the igraph network from the cache.
#' g <- read_drake_graph()
#' class(g) # "igraph"
#' })
#' }
read_drake_graph <- function(
  path = getwd(),
  search = TRUE,
  cache = NULL,
  verbose = drake::default_verbose(),
  ...
){
  if (is.null(cache)){
    cache <- get_cache(path = path, search = search, verbose = verbose)
  }
  if (is.null(cache)){
    stop("cannot find drake cache.")
  }
  if (cache$exists(key = "graph", namespace = "config")){
    cache$get(key = "graph", namespace = "config", use_cache = FALSE)
  } else {
    make_empty_graph()
  }
}

#' @title Read the workflow plan
#'   from your last attempted call to [make()].
#' @description Uses the cache.
#' @seealso [read_drake_config()]
#' @export
#' @return A workflow plan data frame.
#'
#' @inheritParams cached
#'
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_basic_example() # Get the code with drake_example("basic").
#' make(my_plan) # Run the project, build the targets.
#' read_drake_plan() # Retrieve the workflow plan data frame from the cache.
#' })
#' }
read_drake_plan <- function(
  path = getwd(),
  search = TRUE,
  cache = NULL,
  verbose = drake::default_verbose()
){
  if (is.null(cache)){
    cache <- get_cache(path = path, search = search, verbose = verbose)
  }
  if (is.null(cache)){
    stop("cannot find drake cache.")
  }
  if (cache$exists(key = "plan", namespace = "config")){
    cache$get(key = "plan", namespace = "config", use_cache = FALSE)
  } else {
    drake_plan()
  }
}

#' @title Read the pseudo-random number generator seed of the project.
#' @description When a project is created with [make()]
#' or [drake_config()], the project's pseudo-random number generator
#' seed is cached. Then, unless the cache is destroyed,
#' the seeds of all the targets will deterministically depend on
#' this one central seed. That way, reproducibility is protected,
#' even under randomness.
#' @seealso [read_drake_config()]
#' @export
#' @return An integer vector.
#'
#' @inheritParams cached
#'
#' @examples
#' cache <- storr::storr_environment() # Just for the examples.
#' my_plan <- drake_plan(
#'   target1 = sqrt(1234),
#'   target2 = rnorm(n = 1, mean = target1)
#' )
#' tmp <- runif(1) # Needed to get a .Random.seed, but not for drake.
#' digest::digest(.Random.seed) # Fingerprint of the current R session's seed.
#' make(my_plan, cache = cache) # Run the project, build the targets.
#' digest::digest(.Random.seed) # Your session's seed did not change.
#' # Drake uses a hard-coded seed if you do not supply one.
#' read_drake_seed(cache = cache)
#' readd(target2, cache = cache) # Randomly-generated target data.
#' clean(target2, cache = cache) # Oops, I removed the data!
#' tmp <- runif(1) # Maybe the R session's seed also changed.
#' make(my_plan, cache = cache) # Rebuild target2.
#' # Same as before:
#' read_drake_seed(cache = cache)
#' readd(target2, cache = cache)
#' # You can also supply a seed.
#' # If your project already exists, it must agree with the project's
#' # preexisting seed (default: 0)
#' clean(target2, cache = cache)
#' make(my_plan, cache = cache, seed = 0)
#' read_drake_seed(cache = cache)
#' readd(target2, cache = cache)
#' # If you want to supply a different seed than 0,
#' # you need to destroy the cache and start over first.
#' clean(destroy = TRUE, cache = cache)
#' cache <- storr::storr_environment() # Just for the examples.
#' make(my_plan, cache = cache, seed = 1234)
#' read_drake_seed(cache = cache)
#' readd(target2, cache = cache)
read_drake_seed <- function(
  path = getwd(),
  search = TRUE,
  cache = NULL,
  verbose = drake::default_verbose()
){
  if (is.null(cache)){
    cache <- get_cache(path = path, search = search, verbose = verbose)
  }
  if (is.null(cache)){
    stop("cannot find drake cache.")
  }
  if (cache$exists(key = "seed", namespace = "config")){
    cache$get(key = "seed", namespace = "config")
  } else {
    stop("Pseudo-random seed not found in the cache.")
  }
}
