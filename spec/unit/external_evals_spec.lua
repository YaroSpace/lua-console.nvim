local assert = require('luassert.assert')
local match = require('luassert.match')
local h = require('spec_helper')
local vim_system = vim.system

describe('external evaluators', function()
  local config, utils
  local buf
  local content, expected, result
  local _ = match._

  before_each(function()
    utils = require('lua-console.utils')
    config = require('lua-console').setup {
      external_evaluators = { lang_prefix = '&&&' },
    }

    buf = vim.api.nvim_create_buf(true, true)
    vim.bo[buf].filetype = 'ruby'
    vim.api.nvim_set_current_buf(buf)

    content = h.to_table([[ 5.times { puts "Hey" } ]])
    h.set_buffer(buf, content)

    stub(vim, 'system')
  end)

  after_each(function()
    vim.system = vim_system
  end)

  describe('determines correctly the language', function()
    it('determines evaluator based on buffer code prefix', function()
      vim.bo[buf].filetype = ''
      content = h.to_table([[
          &&&ruby

          Some code

          &&&rust
          fn main() {
              let an_integer = 1u32;
              let a_boolean = true;

              let copied_integer = an_integer;
              println!("An integer: {:?}", copied_integer);

              let _unused_variable = 3u32;
              let noisy_unused_variable = 2u32;
          }

          	5.times { puts "Hey" }
			  ]])

      h.set_buffer(buf, content)

      h.send_keys('17gg')
      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        match.assert_arg(function(arg)
          result, expected = arg[1], 'ruby'
          assert.is_same(result, expected)
        end),
        _,
        _
      )
    end)

    it('determines evaluator based on local code prefix', function()
      vim.bo[buf].filetype = ''
      content = h.to_table([[
          &&&racket
          (displayln '(list))

          &&&ruby
          	5.times { puts "Hey" }
			  ]])

      h.set_buffer(buf, content)

      h.send_keys('5gg')
      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        match.assert_arg(function(arg)
          result, expected = arg[1], 'ruby'
          assert.is_same(result, expected)
        end),
        _,
        _
      )
    end)

    it('it determines evaluator based on filetype', function()
      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        match.assert_arg(function(arg)
          result, expected = arg[1], 'ruby'
          assert.is_same(result, expected)
        end),
        _,
        _
      )
    end)
  end)

  describe('calls external evaluator with correct attributes', function()
    it('notifies of an error if external evaluator config cannot be found', function()
      vim.system = vim_system
      stub(vim, 'notify')

      content = h.to_table([[
          &&&scheme
          	(println "Test")
			  ]])

      h.set_buffer(buf, content)

      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.notify).was.called_with(
        match.assert_arg(function(text)
          assert.has_string(text, "No external evaluator for language 'scheme' found")
        end),
        _
      )
    end)

    it('builds command correctly with default config values', function()
      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        match.assert_arg(function(arg)
          result, expected = arg, { 'ruby', '-e', '$stdout.sync = true;5.times { puts "Hey" }' }
          assert.is_same(result, expected)
        end),
        _,
        _
      )
    end)

    it('builds command correctly with custom config values', function()
      config.setup {
        external_evaluators = {
          ruby = {
            cmd = { 'ruby_1', '-t', '-e' },
            env = { RUBY_VERSION = '5.3.0' },
            code_prefix = 'custom_prefix;',
          },
        },
      }

      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        match.assert_arg(function(arg)
          result, expected = arg, { 'ruby_1', '-t', '-e', 'custom_prefix;5.times { puts "Hey" }' }
          assert.is_same(expected, result)
        end),
        _,
        _
      )
    end)

    it('uses default process options', function()
      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        _,
        match.assert_arg(function(arg)
          result = arg
          expected = {
            clear_env = false,
            cmd = { 'ruby', '-e' },
            code_prefix = '$stdout.sync = true;',
            detach = false,
            env = {
              RUBY_VERSION = '3.3.0',
            },
            stdin = false,
            text = true,
          }

          assert.has_properties(result, expected)
          assert.is_function(result.stdout)
          assert.is_function(result.stderr)
          assert.is_function(result.on_exit)
        end),
        _
      )
    end)

    it('uses custom process options', function()
      local custom_opts = {
        external_evaluators = {
          ruby = {
            env = { PATH = 'Test 0' },
            clear_env = 'Test 11',
            stdin = 'Test 21',
            stdout = 'Test 31',
            stderr = 'Test 4',
            text = 'Test 5',
            timeout = 20,
            detach = 'Test 7',
            on_exit = 'Test 8',
          },
        },
      }

      config.setup(custom_opts)

      h.send_keys('Vj')
      utils.eval_code_in_buffer()

      assert.stub(vim.system).was.called_with(
        _,
        match.assert_arg(function(arg)
          result = arg
          assert.has_properties(result, custom_opts.external_evaluators.ruby)
        end),
        _
      )
    end)
  end)

  it('uses removes indentation from code', function()
      config.setup {
        external_evaluators = { ruby = { code_prefix = '' }, }, }

      content = {
		    '  a = [1, 3, 5, 7, 9]',
		    '    for val in a:',
			  '      print(val)'
		  }

      expected = {
		    'a = [1, 3, 5, 7, 9]',
		    '  for val in a:',
			  '    print(val)'
		  }

    h.set_buffer(buf, content)

    h.send_keys('VG')
    utils.eval_code_in_buffer()

    assert.stub(vim.system).was.called_with(
      match.assert_arg(function(arg)
        result = h.to_table(arg[3])
        assert.is_same(result, expected)
      end),
      _,
      _
    )
  end)

  it('uses custom formatter to process results', function()
    vim.system = vim_system
    vim.g._wait_for_spec = false

    result = nil
    local function formatter(ret)
      result = result or ret
      vim.g._wait_for_spec = true

      return {}
    end

    local custom_opts = {
      external_evaluators = {
        ruby = {
          cmd = { 'lua', '-e' },
          formatter = formatter,
        },
      },
    }

    config.setup(custom_opts)

    h.send_keys('Vj')
    utils.eval_code_in_buffer()

    vim.wait(2000, function()
      return vim.g._wait_for_spec
    end, 50)
    assert.has_string(result, 'unexpected symbol near')
  end)

  it('notifies of an error if evaluator cannot be run', function()
    vim.system = vim_system
    stub(vim, 'notify')

    local custom_opts = {
      external_evaluators = {
        ruby = {
          cmd = { 'bad_command', '-e' },
        },
      },
    }

    config.setup(custom_opts)

    h.send_keys('Vj')
    utils.eval_code_in_buffer()

    assert.stub(vim.notify).was.called_with(
      match.assert_arg(function(text)
        assert.has_string(text, 'Could not run external evaluator for lang: ruby')
      end),
      _
    )
  end)
end)
