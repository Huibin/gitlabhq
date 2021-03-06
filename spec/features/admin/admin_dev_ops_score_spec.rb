# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'DevOps Report page' do
  before do
    sign_in(create(:admin))
  end

  it 'has dismissable intro callout', :js do
    visit admin_dev_ops_score_path

    expect(page).to have_content 'Introducing Your DevOps Report'

    find('.js-close-callout').click

    expect(page).not_to have_content 'Introducing Your DevOps Report'
  end

  context 'when usage ping is disabled' do
    before do
      stub_application_setting(usage_ping_enabled: false)
    end

    it 'shows empty state', :js do
      visit admin_dev_ops_score_path

      expect(page).to have_selector(".js-empty-state")
    end

    it 'hides the intro callout' do
      visit admin_dev_ops_score_path

      expect(page).not_to have_content 'Introducing Your DevOps Report'
    end
  end

  context 'when there is no data to display' do
    it 'shows empty state' do
      stub_application_setting(usage_ping_enabled: true)

      visit admin_dev_ops_score_path

      expect(page).to have_content('Data is still calculating')
    end
  end

  context 'when there is data to display' do
    it 'shows numbers for each metric' do
      stub_application_setting(usage_ping_enabled: true)
      create(:dev_ops_score_metric)

      visit admin_dev_ops_score_path

      expect(page).to have_content(
        'Issues created per active user 1.2 You 9.3 Lead 13.3%'
      )
    end
  end
end
