local mason_registry = require('mason-registry')

local function get_jdtls()
  -- Get the path to the JDTL jar where mason installed it
  local jdtls = mason_registry.get_package('jdtls')
  local jdtls_path = jdtls:get_install_path()
  local launcher = vim.fn.glob(jdtls_path .. '/plugins/org.eclipse.equinox.launcher_*.jar')

  local system = 'mac' -- 'mac,linux,win' are the option here
  local config = jdtls_path .. '/config_' .. system

  local lombok = jdtls_path .. '/lombok.jar' -- I don't use this but added for completeness

  return launcher, config, lombok
end

local function get_bundles()
  local java_debug = mason_registry.get_package('java-debug-adapter')
  local java_debug_path = java_debug:get_install_path()

  local bundles = {
    vim.fn.glob(java_debug_path .. '/extension/server/com.microsoft.java.debug.plugin-*.jar')
  }

  local java_test = mason_registry.get_package('java-test')
  local java_test_path = java_test:get_install_path()

  vim.list_extend(bundles, vim.split(vim.fn.glob(java_test_path .. '/extension/server/*.jar'), '\n'))

  return bundles
end

local function get_workspace()
  local home = os.getenv('HOME')
  -- TODO: change me once working correctly
  local workspace_path = home .. '/jdtls_testing'
  local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t')

  local workspace_dir = workspace_path .. '/' .. project_name
  return workspace_dir
end

return {
  "mfussenegger/nvim-jdtls",
  ft = { "java" },
  config = function()

    local jdtls = require("jdtls")
    local jdtls_dap = require("jdtls.dap")
    local jdtls_setup = require("jdtls.setup")

    local launcher, os_config, lombok = get_jdtls()
    local workspace = get_workspace()

    -- LSP settings for Java.
    local on_attach = function(_, bufnr)
      jdtls.setup_dap({ hotcodereplace = "auto" })
      jdtls_dap.setup_dap_main_class_configs()
      --jdtls_setup.add_commands()

      -- Create a command `:Format` local to the LSP buffer
      vim.api.nvim_buf_create_user_command(bufnr, "Format", function(_)
        vim.lsp.buf.format()
      end, { desc = "Format current buffer with LSP" })

      require("lsp_signature").on_attach({
        bind = true,
        padding = "",
        handler_opts = {
          border = "rounded",
        },
        hint_prefix = "󱄑 ",
      }, bufnr)

      -- NOTE: comment out if you don't use Lspsaga
      --    require 'lspsaga'.init_lsp_saga()

    end

    local capabilities = {
      workspace = {
        configuration = true
      },
      textDocument = {
        completion = {
          completionItem = {
            snippetSupport = true
          }
        }
      }
    }

    local config = {
      flags = {
        allow_incremental_sync = true,
      },
      root_dir = jdtls_setup.find_root({ '.git', 'mvnw', 'gradlew', 'pom.xml', 'build.grade'})
    }

    config.cmd = {
      '/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin/java',

      '-Declipse.application=org.eclipse.jdt.ls.core.id1',
      '-Dosgi.bundles.defaultStartLevel=4',
      '-Declipse.product=org.eclipse.jdt.ls.core.product',
      '-Dlog.protocol=true',
      '-Dlog.level=ALL',
      '-Xmx1g',
      '--add-modules=ALL-SYSTEM',
      '--add-opens', 'java.base/java.util=ALL-UNNAMED',
      '--add-opens', 'java.base/java.lang=ALL-UNNAMED',

      '-javaagent:' .. lombok,
      '-jar', launcher,
      '-configuration', os_config,
      '-data', workspace
    }

    config.settings = {
      java = {
        references = {
          includeDecompiledSources = true,
        },
        format = {
          enabled = true,
          settings = {
            url = vim.fn.stdpath("config") .. "/lang-servers/intellij-java-google-style.xml",
            profile = "GoogleStyle",
          },
        },
        eclipse = {
          downloadSources = true,
        },
        maven = {
          downloadSources = true,
        },
        signatureHelp = { enabled = true },
        contentProvider = { preferred = "fernflower" },
        -- eclipse = {
        -- 	downloadSources = true,
        -- },
        -- implementationsCodeLens = {
        -- 	enabled = true,
        -- },
        completion = {
          favoriteStaticMembers = {
            "org.hamcrest.MatcherAssert.assertThat",
            "org.hamcrest.Matchers.*",
            "org.hamcrest.CoreMatchers.*",
            "org.junit.jupiter.api.Assertions.*",
            "java.util.Objects.requireNonNull",
            "java.util.Objects.requireNonNullElse",
            "org.mockito.Mockito.*",
          },
          filteredTypes = {
            "com.sun.*",
            "io.micrometer.shaded.*",
            "java.awt.*",
            "jdk.*",
            "sun.*",
          },
          importOrder = {
            "java",
            "javax",
            "com",
            "org",
          },
        },
        sources = {
          organizeImports = {
            starThreshold = 9999,
            staticStarThreshold = 9999,
          },
        },
        codeGeneration = {
          toString = {
            template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
          },
          hashCodeEquals = {
            useJava7Objects = true
          },
          useBlocks = true,
        },
        configuration = {
          updateBuildConfiguration = "interactive",

          runtimes = {
            {
              name = "JavaSE-11",
              path = "/Library/Java/JavaVirtualMachines/temurin-11.jdk/Contents/Home/",
            },
            {
              name = "JavaSE-17",
              path = "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/",
            }
          }
        }
      },
    }

    config.on_attach = on_attach
    config.capabilities = capabilities

    local extendedClientCapabilities = jdtls.extendedClientCapabilities
    extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

    config.init_options = {
      bundles = get_bundles(),
      extendedClientCapabilities = extendedClientCapabilities,
    }

    -- Start Server
    require('jdtls').start_or_attach(config)

    -- Set Java Specific Keymaps
    --require("jdtls.keymaps")
  end
}
