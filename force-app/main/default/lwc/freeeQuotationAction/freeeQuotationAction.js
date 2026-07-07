import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import { RefreshEvent } from 'lightning/refresh';
import createQuotation from '@salesforce/apex/FreeeQuotationController.createQuotation';

export default class FreeeQuotationAction extends LightningElement {
    @api recordId;
    isLoading = false;
    errorMessage;

    get hasError() {
        return Boolean(this.errorMessage);
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    async handleExecute() {
        this.isLoading = true;
        this.errorMessage = null;

        try {
            const message = await createQuotation({ quotationId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: '成功',
                    message,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new RefreshEvent());
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (error) {
            const message = this.extractErrorMessage(error);
            this.errorMessage = message;

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'freee見積連携に失敗しました',
                    message,
                    variant: 'error',
                    mode: 'sticky'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }

    extractErrorMessage(error) {
        if (Array.isArray(error?.body)) {
            return error.body
                .map((item) => item?.message)
                .filter(Boolean)
                .join('\n');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.body?.output?.errors?.length) {
            return error.body.output.errors
                .map((item) => item?.message)
                .filter(Boolean)
                .join('\n');
        }
        if (error?.message) {
            return error.message;
        }
        return 'freee見積連携に失敗しました。見積の「freee同期メッセージ」またはfreee連携ログを確認してください。';
    }
}
