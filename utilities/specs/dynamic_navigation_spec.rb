# frozen_string_literal: true

require_relative './spec_helper'

RSpec.describe 'dynamic page navigation', type: :feature, js: true do
  let(:first_page) do
    '/bjc-r/cur/programming/2-complexity/4-making-computers-do-math/1-mod-operator.html' \
      '?topic=nyc_bjc%2F2-conditionals-abstraction.topic&course=bjc4nyc.html'
  end

  before do
    visit(first_page)
    expect(page).to have_css('.js-nextPageLink[href]', visible: :visible)
  end

  def visible_next_link
    page.all('.js-nextPageLink[href]', visible: :visible).first
  end

  it 'uses one positive global feature flag' do
    flags = page.evaluate_script(<<~JS)
      Object.keys(window.llab).filter(key =>
        typeof window.llab[key] === 'boolean' &&
        /DYNAMIC.*NAVIGATION|NAVIGATION.*DYNAMIC|DISABLE_DYNAMIC|SKIP_PUSH|PREVENT_NAVIGATION/i.test(key)
      )
    JS

    expect(flags).to eq(['DYNAMIC_NAVIGATION_ENABLED'])
    expect(page.evaluate_script('llab.DYNAMIC_NAVIGATION_ENABLED')).to be(true)
  end

  it 'navigates without reloading and keeps browser history in sync' do
    page.execute_script('window.dynamicNavigationSentinel = true')
    initial_history_length = page.evaluate_script('history.length')

    visible_next_link.click
    expect(page).to have_current_path(/2-math-predicates\.html/, url: true)
    expect(page).to have_content('Making a Mathematical Library')
    expect(page.evaluate_script('window.dynamicNavigationSentinel')).to be(true)
    expect(page.evaluate_script('history.length')).to eq(initial_history_length + 1)

    page.go_back
    expect(page).to have_current_path(/1-mod-operator\.html/, url: true)
    expect(page).to have_content('The Mod Operator')
    expect(page.evaluate_script('window.dynamicNavigationSentinel')).to be(true)
  end

  it 'falls back to normal browser navigation when disabled' do
    page.execute_script(<<~JS)
      llab.DYNAMIC_NAVIGATION_ENABLED = false;
      window.dynamicNavigationSentinel = true;
    JS

    visible_next_link.click
    expect(page).to have_current_path(/2-math-predicates\.html/, url: true)
    expect(page.evaluate_script('window.dynamicNavigationSentinel')).to be_nil
  end

  it 'does not intercept modified clicks' do
    result = page.evaluate_script(<<~JS)
      (() => {
        let loadCalls = 0;
        let prevented = false;
        const originalLoad = llab.loadNewPage;
        llab.loadNewPage = () => { loadCalls += 1; };
        llab.dynamicNavigation('/bjc-r/elsewhere')({
          defaultPrevented: false,
          ctrlKey: true,
          metaKey: false,
          shiftKey: false,
          altKey: false,
          button: 0,
          preventDefault: () => { prevented = true; }
        });
        llab.loadNewPage = originalLoad;
        return { loadCalls, prevented };
      })()
    JS

    expect(result).to eq('loadCalls' => 0, 'prevented' => false)
  end

  it 'binds quiz controls once when rendering a fetched page' do
    self_check = '/bjc-r/cur/programming/2-complexity/unit-2-self-check.html' \
      '?topic=nyc_bjc%2F2-conditionals-abstraction.topic&course=bjc4nyc.html'
    page.execute_script("llab.loadNewPage(#{self_check.inspect})")

    expect(page).to have_css('.checkAnswerButton')
    handler_counts = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.checkAnswerButton')).map(button =>
        (jQuery._data(button, 'events').click || []).length
      )
    JS

    expect(handler_counts).to all(eq(1))
  end

  it 'leaves non-HTML resources to the browser' do
    calls = page.evaluate_script(<<~JS)
      (() => {
        const originalLoad = llab.loadNewPage;
        let loadCalls = 0;
        llab.loadNewPage = () => { loadCalls += 1; };
        const list = $('<ul>').appendTo(document.body);
        llab.renderResource({
          url: '/bjc-r/docs/BJC-Design-Principles.pdf',
          contents: 'PDF'
        }, list);
        const link = list.find('a')[0];
        link.addEventListener('click', event => event.preventDefault());
        link.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
        list.remove();
        llab.loadNewPage = originalLoad;
        return loadCalls;
      })()
    JS

    expect(calls).to eq(0)
  end
end
