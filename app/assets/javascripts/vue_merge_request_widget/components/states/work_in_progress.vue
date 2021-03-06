<script>
import $ from 'jquery';
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';
import { deprecatedCreateFlash as createFlash } from '~/flash';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import mergeRequestQueryVariablesMixin from '../../mixins/merge_request_query_variables';
import getStateQuery from '../../queries/get_state.query.graphql';
import workInProgressQuery from '../../queries/states/work_in_progress.query.graphql';
import removeWipMutation from '../../queries/toggle_wip.mutation.graphql';
import StatusIcon from '../mr_widget_status_icon.vue';
import tooltip from '../../../vue_shared/directives/tooltip';
import eventHub from '../../event_hub';

export default {
  name: 'WorkInProgress',
  components: {
    StatusIcon,
    GlButton,
  },
  directives: {
    tooltip,
  },
  mixins: [glFeatureFlagMixin(), mergeRequestQueryVariablesMixin],
  apollo: {
    userPermissions: {
      query: workInProgressQuery,
      skip() {
        return !this.glFeatures.mergeRequestWidgetGraphql;
      },
      variables() {
        return this.mergeRequestQueryVariables;
      },
      update: data => data.project.mergeRequest.userPermissions,
    },
  },
  props: {
    mr: { type: Object, required: true },
    service: { type: Object, required: true },
  },
  data() {
    return {
      userPermissions: {},
      isMakingRequest: false,
    };
  },
  computed: {
    canUpdate() {
      if (this.glFeatures.mergeRequestWidgetGraphql) {
        return this.userPermissions.updateMergeRequest;
      }

      return Boolean(this.mr.removeWIPPath);
    },
  },
  methods: {
    removeWipMutation() {
      this.isMakingRequest = true;

      this.$apollo
        .mutate({
          mutation: removeWipMutation,
          variables: {
            ...this.mergeRequestQueryVariables,
            wip: false,
          },
          update(
            store,
            {
              data: {
                mergeRequestSetWip: {
                  errors,
                  mergeRequest: { workInProgress, title },
                },
              },
            },
          ) {
            if (errors?.length) {
              createFlash(__('Something went wrong. Please try again.'));

              return;
            }

            const data = store.readQuery({
              query: getStateQuery,
              variables: this.mergeRequestQueryVariables,
            });
            data.project.mergeRequest.workInProgress = workInProgress;
            data.project.mergeRequest.title = title;
            store.writeQuery({
              query: getStateQuery,
              data,
              variables: this.mergeRequestQueryVariables,
            });
          },
          optimisticResponse: {
            // eslint-disable-next-line @gitlab/require-i18n-strings
            __typename: 'Mutation',
            mergeRequestSetWip: {
              __typename: 'MergeRequestSetWipPayload',
              errors: [],
              mergeRequest: {
                __typename: 'MergeRequest',
                title: this.mr.title,
                workInProgress: false,
              },
            },
          },
        })
        .then(({ data: { mergeRequestSetWip: { mergeRequest: { title } } } }) => {
          createFlash(__('The merge request can now be merged.'), 'notice');
          $('.merge-request .detail-page-description .title').text(title);
        })
        .catch(() => createFlash(__('Something went wrong. Please try again.')))
        .finally(() => {
          this.isMakingRequest = false;
        });
    },
    handleRemoveWIP() {
      if (this.glFeatures.mergeRequestWidgetGraphql) {
        this.removeWipMutation();
      } else {
        this.isMakingRequest = true;
        this.service
          .removeWIP()
          .then(res => res.data)
          .then(data => {
            eventHub.$emit('UpdateWidgetData', data);
            createFlash(__('The merge request can now be merged.'), 'notice');
            $('.merge-request .detail-page-description .title').text(this.mr.title);
          })
          .catch(() => {
            this.isMakingRequest = false;
            createFlash(__('Something went wrong. Please try again.'));
          });
      }
    },
  },
};
</script>

<template>
  <div class="mr-widget-body media">
    <status-icon :show-disabled-button="canUpdate" status="warning" />
    <div class="media-body">
      <div class="gl-ml-3 float-left">
        <span class="gl-font-weight-bold">
          {{ __('This merge request is still a work in progress.') }}
        </span>
        <span class="gl-display-block text-muted">{{
          __("Draft merge requests can't be merged.")
        }}</span>
      </div>
      <gl-button
        v-if="canUpdate"
        size="small"
        :disabled="isMakingRequest"
        :loading="isMakingRequest"
        class="js-remove-wip gl-ml-3"
        @click="handleRemoveWIP"
      >
        {{ s__('mrWidget|Mark as ready') }}
      </gl-button>
    </div>
  </div>
</template>
