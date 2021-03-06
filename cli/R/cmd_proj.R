#----------------------------------------------------------------------------#
# RSuite
# Copyright (c) 2017, WLOG Solutions
#
# Handles 'proj' command of CLI utility.
#----------------------------------------------------------------------------#

args <- commandArgs()
base <- dirname(gsub("--file=", "", args[grepl("^--file=", args)]))[1]
if (grepl("darwin", R.version$os)) {
  base <- gsub("~\\+~", " ", base) # on MacOS ~+~ in path denotes whitespace
}
source(file.path(base, "command_mgr.R"), chdir = T)

sub_commands <- list(
  # start ----
  start = list(
    help = "Start new project or update structure of existing one.",
    options = list(
      make_option(c("-n", "--name"), dest = "name",
                  help="Name of the project to create. New project will be created in current directory. (required)"),
      make_option(c("--skip_rc"), dest = "skip_rc", action="store_true", default=FALSE,
                  help="Do not put newly created project under RC (default: %default)"),

      make_option(c("-t", "--tmpl"), dest = "tmpl",
                  help = paste("Name of the project template from the default template directory",
                               "(use rsuite template get to list all available templates in the",
                               "default template directory) or path to package template.",
                               sep = "\n\t\t"))
    ),
    run = function(opts) {
      if (is.null(opts$name) || is.na(opts$name)) {
        stop("Project name is required. Provide --name argument.")
      }

      if (is.null(opts$tmpl) || is.na(opts$tmpl)) {
        opts$tmpl <- "builtin"
      }
      RSuite::prj_start(name = opts$name, skip_rc = opts$skip_rc, tmpl = opts$tmpl)
    }
  ),
  # pkgadd ----
  pkgadd = list(
    help = "Add package to the project.",
    options = list(
      make_option(c("-n", "--name"), dest = "name",
                  help="Name of the package to create. New package will be created in current R project. (required)"),
      make_option(c("--skip_rc"), dest = "skip_rc", action="store_true", default=FALSE,
                  help="Do not put newly created package under RC (default: %default)"),

      make_option(c("-t", "--tmpl"), dest = "tmpl",
                  help = paste("Name of the package template from the default template directory",
                               "(use rsuite template get to list all available templates in the",
                               "default template directory) or path to package template.",
                               sep = "\n\t\t"))
    ),
    run = function(opts) {
      if (is.na(opts$name)) {
        stop("Package name is required. Provide --name argument.")
      }

      if (is.null(opts$tmpl) || is.na(opts$tmpl)) {
        opts$tmpl <- "builtin"
      }
      RSuite::prj_start_package(name = opts$name, skip_rc = opts$skip_rc, tmpl = opts$tmpl)
    }
  ),
  # depsinst ----
  depsinst = list(
    help = "Install required dependencies into project local environment.",
    options = list(
      make_option(c("-c", "--clean"), dest = "clean", action="store_true", default=FALSE,
                  help="Clean local project environment before installing dependencies (default: %default)"),
      make_option(c("--vanilla-sups"), dest = "vanilla_sups", action="store_true", default=FALSE,
                  help=paste("If passed only basic supportive packages will be installed into sandbox",
                             "in case not found in R environment. Basic supportive packages are ones that",
                             "are definitly required to build project packages: roxygen2, devtools or",
                             "vignette builder.",
                             "By default all packages required for package testing and documentation",
                             "building are installed. (default: %default)",
                             sep = "\n\t\t")),
      make_option(c("-r", "--relock"), dest = "relock", action = "store_true",
                   default = FALSE, help = "Allow local project environment relocking (default: %default)")
    ),
    run = function(opts) {
      RSuite::prj_install_deps(clean = opts$clean,
                               relock = opts$relock,
                               vanilla_sups = opts$vanilla_sups)
    }
  ),
  # build ----
  build = list(
    help = "Build the project.",
    options = list(
      make_option(c("-b", "--binary"), dest = "binary", type="logical", default=(.Platform$pkgType != "source"),
                  help="Build binary packages (default: %default)"),
      make_option(c("-f", "--force"), dest = "rebuild", action="store_true", default=FALSE,
                  help="If passed all project packages will be rebuilded even if no changes occured (default: %default)"),
      make_option(c("--no-vignettes"), dest = "no_vignettes", action="store_true", default=FALSE,
                  help="If passed will skip building package's vignettes (default: %default)"),
      make_option(c("--tag"), dest = "tag", action="store_true", default=FALSE,
                  help="If passed will tag packages with RC revision (default: %default)")
    ),
    run = function(opts) {
      pkg_type <- get_pkg_type(opts$binary)
      RSuite::prj_build(type = pkg_type, rebuild = opts$rebuild,
                        vignettes = !opts$no_vignettes,
                        tag = opts$tag)
    }
  ),
  # test ----
  test = list(
    help = "Run tests in tests folder.",
    options = list(
      make_option(c("-d", "--dir"), dest = "tests_dir",
                  help="Folder name relative to project base directory to look for tests. (default: tests)")
    ),
    run = function(opts) {
      if (is.null(opts$tests_dir) || is.na(opts$tests_dir)) {
        opts$tests_dir <- "tests"
      }

      prj <- RSuite::prj_init()
      tests_path <- file.path(prj$path, opts$tests_dir)
      if (!dir.exists(tests_path)) {
        stop(sprintf("Tests folder %s does not exists. Tests cannot be run.", tests_path))
      }
      RSuite::prj_load(prj = prj)
      test_res <- testthat::test_dir(tests_path)
      if (!testthat:::all_passed(test_res)) {
        stop('Tests failed')
      }
    }
  ),
  # depsclean ----
  depsclean = list(
    help = "Uninstall unused dependencies from project local environment.",
    options = list(),
    run = function(opts) {
      RSuite::prj_clean_deps()
    }
  ),
  # zip ----
  zip = list(
    help = "Build project deployment zip package.",
    options = list(
      make_option(c("-p", "--path"), dest = "path",
                  help="Directory to put built zip package into (default: current directory)"),
      make_option(c("--version"), dest = "version",
                  help="Version to use for zip package tagging (default: use ZipVersion form PARAMETERS and revision from RC)"),
      make_option(c("--extras"), dest = "extras",
                  help= paste("Comma separated list extra resources to include into zip package.",
                              "The resource can folder or file which is put into extras subfolder into zip package.",
                              sep = "\n\t\t"))
    ),
    run = function(opts) {
      if (is.null(opts$path) || is.na(opts$path)) {
        opts$path <- getwd()
      }
      if (is.null(opts$version) || is.na(opts$version)) {
        opts$version <- NULL
      }

      # handle extras
      if (is.null(opts$extras) || is.na(opts$extras)) {
        opts$extras <- character(0)
      }
      extras <- trimws(unlist(strsplit(opts$extras, ",")))

      not_found_extras <- extras[!file.exists(extras)]
      if (length(not_found_extras) > 0) {
        stop(sprintf("Extra resources not found: %s", paste(not_found_extras, collapse = ", ")))
      }

      zip_fpath <- RSuite::prj_zip(path = opts$path, zip_ver = opts$version)

      if (length(extras) > 0) {
        loginfo("Injecting extras into deployment zip ...")
        extras_tmp <- tempfile("extras_")

        prj_name <- RSuite::prj_init()$load_params()$project
        extras_dest <- file.path(extras_tmp, prj_name, "extras")
        dir.create(extras_dest, recursive = TRUE)

        on.exit(unlink(extras_tmp, recursive = TRUE, force = TRUE))

        success <- file.copy(extras, extras_dest, recursive = TRUE, overwrite = TRUE)
        failed_extras <- extras[!success]
        if (length(failed_extras) > 0) {
          stop(sprintf("Failed to prepare extras for injection: %s", paste(failed_extras, collapse = ", ")))
        }

        if (!RSuite:::zip_folder(extras_tmp, zip_fpath)) {
          stop(sprintf("Failed to inject extras into %s", zip_fpath))
        }

        loginfo("... done")
      }

      return(invisible(zip_fpath))
    }
  ),
  # inst ----
  inst = list(
    help = "Build project deployment installation package.",
    options = list(
      make_option(c("-p", "--path"), dest = "path",
                  help="Directory to put built installation package into (default: current directory)"),
      make_option(c("--version"), dest = "version",
                  help="Version to use for package tagging (default: use ZipVersion form PARAMETERS and revision from RC)"),
      make_option(c("--extras"), dest = "extras",
                  help= paste("Comma separated list extra resources to include into installation package.",
                              "The resource can folder or file which is put into extras subfolder into package.",
                              sep = "\n\t\t"))
    ),
    run = function(opts) {
      zip_fpath <- sub_commands$zip$run(opts)
      on.exit(unlink(zip_fpath, force = TRUE))
      inst_fpath <- RSuite::inst_wrap_zip(zip_fpath)
      return(invisible(inst_fpath))
    }
  ),
  # pack ----
  pack = list(
    help = "Build project sources pack.",
    options = list(
      make_option(c("-p", "--path"), dest = "path",
                  help="Directory to put built pack into (default: current directory)"),
      make_option(c("--version"), dest = "version",
                  help="Version to use for pack tagging (default: use ZipVersion form PARAMETERS and revision from RC)")
    ),
    run = function(opts) {
      if (is.null(opts$path) || is.na(opts$path)) {
        opts$path <- getwd()
      }
      if (is.null(opts$version) || is.na(opts$version)) {
        opts$version <- NULL
      }
      RSuite::prj_pack(path = opts$path, pack_ver = opts$version)
    }
  ),
  # lock ----
  lock = list(
    help = "Locks the project environment",
    options = list(
    ),
    run = function(opts) {
      RSuite::prj_lock_env()
    }
  ),
  # unlock ----
  unlock = list(
    help = "Unlocks the project environment",
    options = list(
    ),
    run = function(opts) {
      RSuite::prj_unlock_env()
    }
  )
)

# handle ----
handle_subcommands(
  sub_commands = sub_commands,
  cmd_help = "The command helps you manage R projects."
)
